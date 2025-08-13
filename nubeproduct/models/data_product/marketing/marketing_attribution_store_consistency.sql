{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['created_at'],
    partition_by = 'year_month_day_code',
    on_schema_change = 'fail',
    tags = ['daily-10am'] 
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['created_at', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
attribution_data AS (
    SELECT
    DATE(att.created_at) AS created_at
    , att.year_month_day_code
    , COUNT(DISTINCT att.store_id) AS stores_total_attribution
    FROM {{ ref('marketing_attribution_model') }} att
    GROUP BY 1, 2
),
store_info_data AS (
    SELECT
    DATE(msi.created_at) AS created_at
    , CAST(date_format(msi.created_at, 'yyyyMMdd') AS INT) AS year_month_day_code
    , COUNT(DISTINCT msi.store_id) AS stores_total_store_info
    FROM {{ ref('moltres__mwp_store_info') }} msi
    GROUP BY 1, 2
)


SELECT 
  att.created_at
, att.year_month_day_code
, si.stores_total_store_info
, att.stores_total_attribution
, ABS(si.stores_total_store_info - att.stores_total_attribution) AS stores_difference
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by
FROM attribution_data att
LEFT JOIN store_info_data si ON att.year_month_day_code = si.year_month_day_code
LEFT JOIN existing_data e
                          ON att.created_at = e.created_at
WHERE
    {% if not is_incremental() %}
      att.created_at >= DATE '2010-01-01'
    {% endif %}
    {% if is_incremental() %}
      att.created_at > (
        SELECT COALESCE(date_sub(MAX(created_at), 1), DATE '1900-01-01') FROM {{ this }}
      )
    {% endif %}