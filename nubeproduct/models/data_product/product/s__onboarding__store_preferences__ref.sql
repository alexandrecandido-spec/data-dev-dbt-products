{{
    config(
        materialized='incremental',
        unique_key= 'store_id',
        on_schema_change='append_new_columns', 
        tags=['daily-10am'] 
    )
}}

WITH main AS (
    SELECT
        store_id, 
        created_at
    FROM
        {{ ref('moltres__mwp_store_info') }}
    WHERE is_store_blocked IS FALSE
    
    {% if is_incremental() %}
    AND sys_audit_updated_on >= (select coalesce(DATE_SUB(max(sys_audit_updated_on), 1), '1900-01-01') from {{ this }} )
    {% else %}
    AND DATE(created_at) >= add_months(current_date(), -12)
    {% endif %}

),

answers AS (
    SELECT * 
    FROM {{ ref('_int_onboarding_store_preferences') }}
),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

agg AS(
    SELECT
    m.store_id,
    m.created_at,
    concat_ws(', ', collect_set(CASE WHEN a.group_code LIKE '%sales_status%' THEN a.description ELSE NULL END)) AS sales_status,
    concat_ws(', ', collect_set(CASE WHEN a.group_code LIKE '%platform%' THEN a.description ELSE NULL END)) AS sales_platform,
    concat_ws(', ', collect_set(CASE WHEN a.group_code LIKE '%platform%' THEN a.free_text ELSE NULL END)) AS sales_platform_text,
    concat_ws(', ', collect_set(CASE WHEN a.group_code LIKE '%sales_amount%' THEN a.description ELSE NULL END)) AS sales_amount,
    concat_ws(', ', collect_set(CASE WHEN a.group_code LIKE '%channel%' THEN a.description ELSE NULL END)) AS sales_channel,
    concat_ws(', ', collect_set(CASE WHEN a.group_code LIKE '%product_type%' THEN a.description ELSE NULL END)) AS sales_products,
    concat_ws(', ', collect_set(CASE WHEN a.group_code LIKE '%product_type%' THEN a.free_text ELSE NULL END)) AS sales_products_text,
    concat_ws(', ', collect_set(CASE WHEN a.group_code LIKE '%sales_product%' THEN a.description ELSE NULL END)) AS sales_product_kind
FROM main m
LEFT JOIN answers a
    ON m.store_id = a.store_id
GROUP BY
    m.store_id, m.created_at
)

SELECT 
    agg.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM agg
LEFT JOIN existing_data e ON agg.store_id = e.store_id 