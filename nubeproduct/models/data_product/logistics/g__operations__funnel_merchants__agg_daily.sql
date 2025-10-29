-- Final data product for merchant-level funnel analysis.
-- Each row represents the number of merchants that reached a given funnel stage 
-- (tier) for a specific time period and granularity (day, week, month).
-- Used for business monitoring, product adoption KPIs, and churn prevention analysis.

{{ 
    config(
        materialized='table', 
        on_schema_change='fail',
        tags = ["logistics", "daily-8am"]
    ) 
}}


SELECT
    granularity,
    tier,
    current_segment,
    vertical_name,
    plan,
    country,
    ref_period,
    qty,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_logistics_funnel__merchants_general') }}