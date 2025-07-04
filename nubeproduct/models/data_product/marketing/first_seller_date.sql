{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        partition_by = 'year_month_day_code',
        on_schema_change='fail',
        tags=["marketing","daily-9am"]
    )
}}

WITH marketing AS (
    SELECT store_id, 
            year_month_day_code
    FROM {{ ref('marketing_attribution_model') }}
    WHERE year_month_day_code >= 20230101
),
qualified_orders as (
    SELECT *
    FROM {{ ref('_int__first_seller_7_or_more_sales_90d') }}
),
first_seller AS (
    SELECT 
        ma.store_id,
        ma.year_month_day_code,
        DATE(min(fs.completed_at)) AS first_seller_at
FROM marketing ma
LEFT JOIN qualified_orders fs ON ma.store_id = fs.store_id
GROUP BY ma.store_id,  ma.year_month_day_code
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)
SELECT
    f.store_id, 
    f.year_month_day_code,
    f.first_seller_at,
    COALESCE(e.sys_audit_created_on, current_timestamp()) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp() AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM first_seller f
LEFT JOIN existing_data e ON f.store_id = e.store_id 
WHERE
    {% if not is_incremental() %}
      first_seller_at >= DATE '2023-01-01'
    {% endif %}
    {% if is_incremental() %}
     first_seller_at is not null
        FROM {{ this }}
    {% endif %}
