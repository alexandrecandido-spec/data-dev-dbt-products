{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        partition_by = 'year_month_day_code',
        on_schema_change='fail',
        tags=['daily-9am']
    )
}}

WITH stores AS (
    SELECT 
        msi.store_id, 
        msi.created_at
    FROM {{ ref('moltres__mwp_store_info') }} as msi
),
qualified_orders as (
    SELECT
        store_id,
        DATE(min(completed_at)) AS first_seller_at
    FROM {{ ref('_int_marketing__first_seller_7_or_more_sales_90d') }}
    GROUP BY store_id
),
first_seller AS (
    SELECT 
        s.store_id,
        CAST(date_format(s.created_at, 'yyyyMMdd') AS INT) AS year_month_day_code,
        q.first_seller_at
FROM stores s
LEFT JOIN qualified_orders q ON s.store_id = q.store_id
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
     (first_seller_at >= DATE '2023-01-01' OR first_seller_at IS NULL)
    {% endif %}
    {% if is_incremental() %}
     (
        first_seller_at > (
           SELECT COALESCE(MAX(first_seller_at), DATE '1900-01-01')
           FROM {{ this }}
          )
        OR first_seller_at IS NULL
     )
    {% endif %}
