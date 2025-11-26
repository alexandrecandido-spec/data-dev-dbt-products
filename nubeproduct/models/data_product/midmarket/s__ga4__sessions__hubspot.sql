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

-- ✅ Dummy inicial: permite que o dbt injete CTEs antes sem erro de sintaxe
WITH dummy AS (SELECT 1 AS keepalive)

{% if is_incremental() %}
, max_event_date_cte AS (
    SELECT
        COALESCE(
            date_add(date(MAX(date_time)), -5),   -- usa o campo date_time do alvo
            to_date('{{ dp_start }}')
        ) AS max_event_date
    FROM {{ this }}
)
{% endif %}

, base AS (
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
        {% if is_incremental() %}
          AND date(from_unixtime(event_timestamp / 1000000)) >= (SELECT max_event_date FROM max_event_date_cte)
        {% endif %}
)

, pageviews_with_guid_raw AS (
    SELECT
        user_pseudo_id,
        regexp_extract(
            element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value,
            'submissionGuid=([0-9a-fA-F\\-]{36})',
            1
        ) AS hubspot_conversion_id
    FROM base
    WHERE event_name = 'page_view'
      AND element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value LIKE '%submissionGuid=%'
)

, pageviews_with_guid AS (
    SELECT
        user_pseudo_id,
        MAX(hubspot_conversion_id) AS hubspot_conversion_id
    FROM pageviews_with_guid_raw
    GROUP BY user_pseudo_id
)

-- 1️⃣ Session_start events
, session_start_events AS (
    SELECT DISTINCT
        date_time,
        event_timestamp,
        user_pseudo_id,
        element_at(filter(event_params, x -> x.key = 'ga_session_number'), 1).value.int_value AS session_number,
        traffic_source.source AS session_source,
        traffic_source.medium AS session_medium,
        traffic_source.name   AS session_campaign,
        device_category       AS session_device,
        'session_start'       AS event_type
    FROM base
    WHERE event_name = 'session_start'
)

-- 2️⃣ Page_view events com extração de UTM
, page_view_events AS (
    SELECT DISTINCT
        date_time,
        event_timestamp,
        user_pseudo_id,
        element_at(filter(event_params, x -> x.key = 'ga_session_number'), 1).value.int_value AS session_number,
        regexp_extract(element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value, 'utm_source=([^&]*)', 1)   AS url_source,
        regexp_extract(element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value, 'utm_medium=([^&]*)', 1)   AS url_medium,
        regexp_extract(element_at(filter(event_params, x -> x.key = 'page_location'), 1).value.string_value, 'utm_campaign=([^&]*)', 1) AS url_campaign,
        traffic_source.source AS traffic_source_source,
        traffic_source.medium AS traffic_source_medium,
        traffic_source.name   AS traffic_source_campaign,
        device_category AS session_device
    FROM base
    WHERE event_name = 'page_view'
)

-- 3️⃣ Filtragem e fallback
, filtered_page_views AS (
    SELECT DISTINCT
        date_time,
        event_timestamp,
        user_pseudo_id,
        session_number,
        CASE
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
        (
            COALESCE(url_source,   '') <> COALESCE(traffic_source_source,   '')
         OR COALESCE(url_medium,   '') <> COALESCE(traffic_source_medium,   '')
         OR COALESCE(url_campaign, '') <> COALESCE(traffic_source_campaign, '')
        )
        OR (
            (traffic_source_source IS NULL AND traffic_source_medium IS NULL AND traffic_source_campaign IS NULL)
            AND (url_source IS NOT NULL OR url_medium IS NOT NULL OR url_campaign IS NOT NULL)
        )
        OR (
            (traffic_source_source IS NULL AND traffic_source_medium IS NULL AND traffic_source_campaign IS NULL)
            AND (url_source IS NULL AND url_medium IS NULL AND url_campaign IS NULL)
        )
)

-- 4️⃣ União e deduplicação com ROW_NUMBER
, unioned AS (
    SELECT * FROM session_start_events
    UNION ALL
    SELECT * FROM filtered_page_views
)

, ranked AS (
    SELECT
        date_time,
        event_timestamp,
        user_pseudo_id,
        session_number,
        session_source,
        session_medium,
        session_campaign,
        session_device,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id, event_timestamp
            ORDER BY CASE WHEN event_type = 'session_start' THEN 1 ELSE 2 END, date_time DESC
        ) AS rn
    FROM unioned
)

-- 5️⃣ Resultado final deduplicado 1:1 com GUID
SELECT
    r.date_time,
    r.event_timestamp,
    r.user_pseudo_id,
    r.session_number,
    r.session_source,
    r.session_medium,
    r.session_campaign,
    r.session_device,
    r.event_type,
    g.hubspot_conversion_id
FROM ranked r
JOIN pageviews_with_guid g
  ON r.user_pseudo_id = g.user_pseudo_id
WHERE r.rn = 1