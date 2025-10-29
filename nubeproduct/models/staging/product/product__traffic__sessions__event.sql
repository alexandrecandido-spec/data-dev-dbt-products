{{ config(
    materialized = 'incremental',
    unique_key = 'unique_session_key',
    partition_by = 'base_date',
    on_schema_change = 'fail',
    tags = ['product', 'daily-2am']
) }}

WITH raw_sessions AS (
SELECT
    MD5(CONCAT_WS('_', session_id, consumer_id, store_id)) AS unique_session_key
    , timestamp AS session_timestamp
    , DATE(timestamp) AS base_date
    , session_id
    , consumer_id
    , store_id
    , country AS visitor_country
    , device
    , theme
    , user_agent
    , ip_address
    , NULLIF(LOWER(utm_source), '')   AS utm_source
    , NULLIF(LOWER(utm_medium), '')   AS utm_medium
    , NULLIF(LOWER(utm_campaign), '') AS utm_campaign
    , NULLIF(LOWER(utm_term), '')     AS utm_term
    , NULLIF(LOWER(utm_content), '')  AS utm_content
    , NULLIF(LOWER(landing_page), '') AS landing_page
    , NULLIF(LOWER(http_referral), '') AS http_referral
FROM
    {{ source('stg_storefronts', 'sessions') }}
WHERE 
    {% if not is_incremental() %}
    TO_DATE(date_id, 'yyyyMMdd') BETWEEN DATE('2024-01-01') AND DATE('2024-01-05')
    {% else %}
    TO_DATE(date_id, 'yyyyMMdd') {{ get_max_date(this, 'base_date', 1, 'month') }}
    {% endif %}
)

, deduped_sessions AS (
SELECT
    *
FROM (
    SELECT
        *
        , ROW_NUMBER() OVER (PARTITION BY unique_session_key ORDER BY session_timestamp ASC) AS row_num
    FROM raw_sessions
) sub
WHERE row_num = 1
)

, existing_data AS (
    {{ get_existing_data(this, ['unique_session_key'])}}
)

SELECT
    dds.unique_session_key
    , dds.session_timestamp
    , dds.base_date
    , dds.session_id
    , dds.consumer_id
    , dds.store_id
    , dds.visitor_country
    , dds.device
    , dds.theme
    , dds.user_agent
    , dds.ip_address
    , dds.utm_source
    , dds.utm_medium
    , dds.utm_campaign
    , dds.utm_term
    , dds.utm_content
    , dds.landing_page
    , dds.http_referral
    , CURRENT_TIMESTAMP AS sys_audit_created_on
    , 'data-dev-dbt-products' AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    deduped_sessions AS dds
LEFT JOIN
    existing_data
    ON dds.unique_session_key = existing_data.unique_session_key
WHERE
    existing_data.unique_session_key IS NULL