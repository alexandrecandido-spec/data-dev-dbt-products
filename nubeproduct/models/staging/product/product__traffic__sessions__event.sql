{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    incremental_predicates = [
        'DBT_INTERNAL_SOURCE.base_date = DBT_INTERNAL_DEST.base_date',
        'DBT_INTERNAL_SOURCE.unique_session_key = DBT_INTERNAL_DEST.unique_session_key'
    ],
    unique_key = ['unique_session_key', 'base_date'],
    partition_by = 'base_date',
    on_schema_change = 'fail',
    tags = ['product', 'daily-2am'],
    pre_hook = [
        "DELETE FROM {{ this }} WHERE base_date BETWEEN DATE('2024-10-13') AND DATE('2024-12-19')"
    ]
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
    TO_DATE(date_id, 'yyyyMMdd') BETWEEN DATE('2024-10-13') AND DATE('2024-12-19')
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
) AS sub
WHERE 
    row_num = 1
)

SELECT
    unique_session_key
    , session_timestamp
    , base_date
    , session_id
    , consumer_id
    , store_id
    , visitor_country
    , device
    , theme
    , user_agent
    , ip_address
    , utm_source
    , utm_medium
    , utm_campaign
    , utm_term
    , utm_content
    , landing_page
    , http_referral
    , CURRENT_TIMESTAMP AS sys_audit_created_on
    , 'data-dev-dbt-products' AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM 
    deduped_sessions
