{{
    config(
        materialized='incremental',
        unique_key=['event_bundle_sequence_id', 'event_timestamp', 'user_pseudo_id', 'batch_event_index', 'event_name'],
        partition_by='year_month_day_code',
        on_schema_change='fail',
        tags=["marketing","daily-8am"]
    )
}}

WITH source AS ( 
    SELECT 
        event_bundle_sequence_id,
        event_timestamp,
        COALESCE(user_pseudo_id, 'no_user') AS user_pseudo_id,
        COALESCE(batch_event_index, -1) AS batch_event_index,
        COALESCE(event_name, 'no_event') AS event_name,
        source,
        event_params,
        event_date,
        -- novo campo adicionado
        traffic_source,

        device.category AS device_category,
        geo.country AS country,
        geo.region AS region,
        year_month_code
    FROM {{ source('stg_marketing', 'analytics_events') }} AS events
    {% if is_incremental() %}
    WHERE       event_date >= (SELECT MAX(event_date) - 5 FROM {{ this }})
       AND year_month_code >= (SELECT MAX(CAST(SUBSTR(event_date, 1, 6) AS INT)) AS max_year_month FROM {{ this }})
    {% endif %}
),

ranked_source AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY event_bundle_sequence_id, event_timestamp, user_pseudo_id, batch_event_index, event_name
            ORDER BY event_date DESC, year_month_code DESC
        ) AS _rn
    FROM source s
),

dedup_source AS (
    SELECT * FROM ranked_source WHERE _rn = 1
),

existing_data AS (
    {{ get_existing_data(this, [
        'event_bundle_sequence_id',
        'event_timestamp',
        'user_pseudo_id',
        'batch_event_index',
        'event_name',
        'sys_audit_created_on',
        'sys_audit_created_by'
    ]) }}
)

SELECT 
    d.source,
    d.event_bundle_sequence_id,
    d.batch_event_index,
    d.user_pseudo_id,
    CONCAT(d.source, '-', d.user_pseudo_id) AS id,

    COALESCE(
        CAST(element_at(filter(d.event_params, x -> x.key = 'ga_session_id'), 1).value.int_value AS BIGINT),
        CAST(element_at(filter(d.event_params, x -> x.key = 'ga_session_id'), 1).value.string_value AS BIGINT)
    ) AS ga_session_id,

    CONCAT(
        d.source, '-', d.user_pseudo_id, '-', CAST(
            COALESCE(
                CAST(element_at(filter(d.event_params, x -> x.key = 'ga_session_id'), 1).value.int_value AS STRING),
                CAST(element_at(filter(d.event_params, x -> x.key = 'ga_session_id'), 1).value.string_value AS STRING)
            ) AS STRING)
    ) AS unique_session,

    d.event_name,
    d.event_params,
    d.event_date,
    d.event_timestamp,
    d.device_category,
    d.traffic_source, -- adicionado
    d.country,
    d.region,
    d.year_month_code,
    CAST(date_format(d.event_date, 'yyyyMMdd') AS INT) AS year_month_day_code,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM dedup_source d
LEFT JOIN existing_data e
    ON d.event_bundle_sequence_id = e.event_bundle_sequence_id
   AND d.event_timestamp          = e.event_timestamp
   AND d.user_pseudo_id           = e.user_pseudo_id
   AND d.batch_event_index        = e.batch_event_index
   AND d.event_name               = e.event_name
