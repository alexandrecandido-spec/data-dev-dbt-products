{{ config(
    materialized = 'incremental',
    unique_key = 'unique_session_key',
    partition_by = 'base_date',
    on_schema_change = 'fail',
    tags = ['product', 'daily-2am']
) }}

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
    , CURRENT_TIMESTAMP AS sys_audit_created_on
    , 'data-dev-dbt-products' AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    {{ source('stg_storefronts', 'sessions') }}
WHERE 
    {% if not is_incremental() %}
    TO_DATE(date_id, 'yyyyMMdd') BETWEEN DATE('2024-01-01') AND DATE('2024-01-05')
    {% else %}
    TO_DATE(date_id, 'yyyyMMdd') {{ get_max_date(this, 'base_date', 2, 'month') }}
    {% endif %}

