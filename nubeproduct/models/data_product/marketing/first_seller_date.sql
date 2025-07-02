{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=["marketing","daily-9am"]
    )
}}

WITH marketing AS (
    SELECT *
    FROM {{ ref('marketing_attribution_model') }}
    WHERE year_month_day_code >= 20200101
),
qualified_orders as (
    SELECT *
    FROM {{ ref('_int__first_seller_7_or_more_sales_90d') }}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)


SELECT
    ma.store_id,
    DATE(min(fs.completed_at)) AS first_seller_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM marketing ma
LEFT JOIN qualified_orders fs ON ma.store_id = fs.store_id
LEFT JOIN existing_data e ON ma.store_id = e.store_id 
WHERE
    {% if not is_incremental() %}
      sys_audit_updated_on >= DATE '2020-01-01'
    {% endif %}
    {% if is_incremental() %}
     sys_audit_updated_on > (
        SELECT COALESCE(MAX(sys_audit_updated_on), DATE '2020-01-01')
        FROM {{ this }}
      )
    {% endif %}
GROUP BY ma.store_id, sys_audit_created_on, sys_audit_created_by, sys_audit_updated_on, sys_audit_updated_by
