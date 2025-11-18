{{
    config(
        materialized='incremental',
        unique_key=['user_pseudo_id', 'event_timestamp'],
        on_schema_change='fail',
        tags=["midmarket","daily-9am"]
    )
}}

{% set dp_start = var('ga4_hs_start_date', '2023-01-01') %}
{% set dp_end = var('ga4_hs_end_date', none) %}

WITH base AS (
    SELECT
        event_name,
        event_date,
        event_timestamp,
        user_pseudo_id,
        event_params,
        traffic_source,
        device_category,
        from_unixtime(event_timestamp / 1000000) AS date_time
    FROM {{ ref('marketing__analytics_events') }}
    WHERE
        to_date(event_date, 'yyyyMMdd') >= to_date('{{ dp_start }}')
        {% if dp_end %}
          AND to_date(event_date, 'yyyyMMdd') <= to_date('{{ dp_end }}')
        {% endif %}
        AND event_name IN ('page_view', 'session_start')
),

pageviews_with_guid AS (
    SELECT DISTINCT
        user_pseudo_id,
        regexp_extract(
            element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value,
            'submissionGuid=([0-9a-fA-F\\-]{36})',
            1
        ) AS hubspot_conversion_id
    FROM base
    WHERE event_name = 'page_view'
      AND element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value LIKE '%submissionGuid=%'
),

-- 1️⃣ Session_start events: always included
session_start_events AS (
    SELECT DISTINCT
        date_time,
        event_timestamp,
        user_pseudo_id,
        element_at(filter(event_params, x -> x.key = 'ga_session_number'), 1).value.int_value AS session_number,
        traffic_source.source AS session_source,
        traffic_source.medium AS session_medium,
        traffic_source.name AS session_campaign,
        device_category AS session_device,
        'session_start' AS event_type
    FROM base
    WHERE event_name = 'session_start'
),

-- 2️⃣ Page_view events
page_view_events AS (
    SELECT DISTINCT
        date_time,
        event_timestamp,
        user_pseudo_id,
        element_at(filter(event_params, x -> x.key = 'ga_session_number'), 1).value.int_value AS session_number,

        -- Extract UTM parameters from the URL
        regexp_extract(element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value, 'utm_source=([^&]*)', 1) AS url_source,
        regexp_extract(element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value, 'utm_medium=([^&]*)', 1) AS url_medium,
        regexp_extract(element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value, 'utm_campaign=([^&]*)', 1) AS url_campaign,

        -- GA4 traffic source struct
        traffic_source.source  AS traffic_source_source,
        traffic_source.medium  AS traffic_source_medium,
        traffic_source.name    AS traffic_source_campaign,

        device_category AS session_device
    FROM base
    WHERE event_name = 'page_view'
),

-- 3️⃣ Filtering and fallback logic
filtered_page_views AS (
    SELECT DISTINCT
        date_time,
        event_timestamp,
        user_pseudo_id,
        session_number,

        CASE
            -- Case 5: no traffic_source and no UTM → direct
            WHEN (traffic_source_source IS NULL AND traffic_source_medium IS NULL AND traffic_source_campaign IS NULL)
                 AND (url_source IS NULL AND url_medium IS NULL AND url_campaign IS NULL)
            THEN '(direct)'
            ELSE COALESCE(url_source, traffic_source_source, '(direct)')
        END AS session_source,

        CASE
            WHEN (traffic_source_source IS NULL AND traffic_source_medium IS NULL AND traffic_source_campaign IS NULL)
                 AND (url_source IS NULL AND url_medium IS NULL AND url_campaign IS NULL)
            THEN '(none)'
            ELSE COALESCE(url_medium, traffic_source_medium, '(none)')
        END AS session_medium,

        CASE
            WHEN (traffic_source_source IS NULL AND traffic_source_medium IS NULL AND traffic_source_campaign IS NULL)
                 AND (url_source IS NULL AND url_medium IS NULL AND url_campaign IS NULL)
            THEN '(direct)'
            ELSE COALESCE(url_campaign, traffic_source_campaign, '(direct)')
        END AS session_campaign,

        session_device,
        'page_view' AS event_type
    FROM page_view_events
    WHERE
        -- Case 2: traffic_source populated but UTMs differ
        (
            COALESCE(url_source, '') <> COALESCE(traffic_source_source, '')
            OR COALESCE(url_medium, '') <> COALESCE(traffic_source_medium, '')
            OR COALESCE(url_campaign, '') <> COALESCE(traffic_source_campaign, '')
        )
        OR
        -- Case 4: empty traffic_source but UTM present
        (
            (traffic_source_source IS NULL AND traffic_source_medium IS NULL AND traffic_source_campaign IS NULL)
            AND (url_source IS NOT NULL OR url_medium IS NOT NULL OR url_campaign IS NOT NULL)
        )
        OR
        -- Case 5: empty traffic_source and no UTM (direct)
        (
            (traffic_source_source IS NULL AND traffic_source_medium IS NULL AND traffic_source_campaign IS NULL)
            AND (url_source IS NULL AND url_medium IS NULL AND url_campaign IS NULL)
        )
)

-- 4️⃣ Merge both sets and join with HubSpot GUID
SELECT DISTINCT
    s.date_time,
    s.event_timestamp,
    s.user_pseudo_id,
    s.session_number,
    s.session_source,
    s.session_medium,
    s.session_campaign,
    s.session_device,
    s.event_type,
    g.hubspot_conversion_id
FROM (
    SELECT * FROM session_start_events
    UNION ALL
    SELECT * FROM filtered_page_views
) s
INNER JOIN pageviews_with_guid g
    ON s.user_pseudo_id = g.user_pseudo_id