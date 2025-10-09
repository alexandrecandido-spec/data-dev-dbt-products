{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key=['date','full_url','path','search_type'],
  on_schema_change='fail',
  tags=['daily-7am','marketing']
) }}

WITH source AS (
    SELECT
        CAST(date AS DATE) AS date,
        CAST(full_url AS STRING) AS full_url,
        CAST(path AS STRING) AS path,
        CAST(search_type AS STRING) AS search_type,
        CAST(NULL AS STRING) AS country_name,
        CAST(NULL AS STRING) AS device,
        CAST(impressions AS INT) AS impressions,
        CAST(clicks AS INT) AS clicks,
        CAST(position AS INT) AS average_position
    FROM {{ source('stg_third_party', 'marketing_google_search_console_urls_unsplit_results') }}
    {% if is_incremental() %}
        WHERE sys_audit_updated_on >= (SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') FROM {{ this }})
    {% endif %}
),
-- como funciona isso? 
existing_data AS (
    {{ get_existing_data(this, ['date','full_url','path','search_type','country_name','device','sys_audit_created_on','sys_audit_created_by']) }}
)
SELECT
    source.*,
    CAST(COALESCE(e.sys_audit_created_on, current_timestamp) AS TIMESTAMP) AS sys_audit_created_on,
    CAST(COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS STRING) AS sys_audit_created_by,
    CAST(current_timestamp AS TIMESTAMP) AS sys_audit_updated_on,
    CAST('data-dev-dbt-products' AS STRING) AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e 
    ON source.date = e.date 
    AND source.full_url = e.full_url 
    AND source.path = e.path 
    AND source.search_type = e.search_type
    AND COALESCE(source.country_name, 'x') = COALESCE(e.country_name, 'x')
    AND COALESCE(source.device, 'x') = COALESCE(e.device, 'x')
