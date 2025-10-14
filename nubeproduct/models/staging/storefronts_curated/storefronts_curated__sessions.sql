{{ config(
    materialized = 'incremental',
    unique_key = 'unique_session_key',
    partition_by = 'base_date',
    on_schema_change = 'fail',
    tags = ['product', 'daily-2am']
) }}

WITH sessions AS (
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
    TO_DATE(date_id, 'yyyyMMdd') {{ get_max_date(this, 'base_date', 1, 'week') }}
    {% endif %}
)

, existing_data AS (
    {{ get_existing_data(this, ['unique_session_key', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    sessions.unique_session_key
    , sessions.session_timestamp
    , sessions.base_date
    , sessions.session_id
    , sessions.consumer_id
    , sessions.store_id
    , sessions.visitor_country
    , sessions.device
    , sessions.theme
    , sessions.user_agent
    , sessions.ip_address
    , sessions.utm_source
    , sessions.utm_medium
    , sessions.utm_campaign
    , sessions.utm_term
    , sessions.utm_content
    , sessions.landing_page
    , sessions.http_referral
    , COALESCE(existing_data.sys_audit_created_on, CURRENT_TIMESTAMP) AS sys_audit_created_on
    , COALESCE(existing_data.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM 
    sessions
LEFT JOIN 
    existing_data 
    ON sessions.unique_session_key = existing_data.unique_session_key
