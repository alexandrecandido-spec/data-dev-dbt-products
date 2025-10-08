{{ config(
    materialized = 'incremental',
    unique_key = 'unique_session_key',
    partition_by = 'base_date',
    on_schema_change = 'fail',
    tags = ['product', 'daily-9pm']
) }}

WITH sessions AS (
SELECT
    MD5(CONCAT_WS('_', session_id, consumer_id, store_id)) AS unique_session_key
    , ses.timestamp AS session_timestamp
    , DATE(ses.timestamp) AS base_date
    , ses.session_id
    , ses.consumer_id
    , ses.store_id
    , ses.country AS visitor_country
    , ses.device
    , ses.theme
    , ses.user_agent
    , ses.ip_address
    , NULLIF(LOWER(ses.utm_source), '')   AS utm_source
    , NULLIF(LOWER(ses.utm_medium), '')   AS utm_medium
    , NULLIF(LOWER(ses.utm_campaign), '') AS utm_campaign
    , NULLIF(LOWER(ses.utm_term), '')     AS utm_term
    , NULLIF(LOWER(ses.utm_content), '')  AS utm_content
    , NULLIF(LOWER(ses.landing_page), '') AS landing_page
    , NULLIF(LOWER(ses.http_referral), '') AS http_referral
FROM
    {{ source('stg_storefronts', 'sessions') }} AS ses
WHERE 
    DATE(ses.timestamp) >= DATE('2024-01-01')

    {% if is_incremental() %}
    AND ses.date_id >= DATE_FORMAT((SELECT MAX(base_date) FROM {{ this }}), 'yyyyMMdd')
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
