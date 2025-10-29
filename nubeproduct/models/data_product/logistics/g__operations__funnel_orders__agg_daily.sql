-- Final data product for order-level funnel analysis.
-- Provides a detailed view of how shipments move across funnel stages 
-- while preserving store-level dimensions (segment, plan, vertical, etc.).
-- Enables performance tracking and behavioral analysis across merchant cohorts.


{{ 
    config(
        materialized='table', 
        on_schema_change='fail',
        tags = ["logistics", "daily-8am"]
    ) 
}}

SELECT
    tier,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    ref_date,
    ref_week,
    ref_month,
    country,
    qty,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_logistics_funnel__orders_general') }}