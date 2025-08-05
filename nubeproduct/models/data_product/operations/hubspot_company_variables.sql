{{
    config(
        materialized='table',
        tags=['daily-6am']
    )
}}

WITH existing_data AS ({{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }})

,dependency_audit_dates AS
(
SELECT
 a.store_id
,GREATEST(
    a.sys_audit_updated_on,
    COALESCE(b.sys_audit_updated_on, a.sys_audit_updated_on),
    COALESCE(c.sys_audit_updated_on, a.sys_audit_updated_on),
    COALESCE(d.sys_audit_updated_on, a.sys_audit_updated_on),
    COALESCE(e.sys_audit_updated_on, a.sys_audit_updated_on),
    COALESCE(f.sys_audit_updated_on, a.sys_audit_updated_on),
    COALESCE(g.sys_audit_updated_on, a.sys_audit_updated_on),
    COALESCE(h.sys_audit_updated_on, a.sys_audit_updated_on)
 ) AS max_dependency_audit_date
FROM      {{ ref('dim_merchant_info') }}    a
LEFT JOIN {{ ref('dim_location_country') }} b ON b.country_id       = a.country_id
LEFT JOIN {{ ref('dim_location_country') }} c ON c.country_id       = a.base_country_id
LEFT JOIN {{ ref('dim_location_region') }}  d ON d.region_id        = a.base_region_id
LEFT JOIN {{ ref('dim_location_state') }}   e ON e.state_id         = a.base_state_id
LEFT JOIN {{ ref('dim_location_city') }}    f ON f.city_id          = a.base_city_id
LEFT JOIN {{ ref('dim_segment_type') }}     g ON g.segment_id       = a.current_segment_id
LEFT JOIN {{ ref('dim_vertical_type') }}    h ON h.vertical_id      = a.vertical_id
)

,merchant_info AS
(
SELECT
 a.store_id
,COALESCE(g.segment_name, '') AS status_by_order_str
,COALESCE(i.vertical_name, '') AS vertical_str
,dad.max_dependency_audit_date
FROM      {{ ref('dim_merchant_info') }}    a
LEFT JOIN {{ ref('dim_segment_type') }}     g ON g.segment_id       = a.current_segment_id
LEFT JOIN {{ ref('dim_vertical_type') }}    i ON i.vertical_id      = a.vertical_id
LEFT JOIN dependency_audit_dates           dad ON dad.store_id      = a.store_id
)

SELECT
 a.store_id
,a.status_by_order_str
,a.vertical_str
,COALESCE(b.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
,COALESCE(b.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
,a.max_dependency_audit_date AS sys_audit_updated_on
,'data-dev-dbt-products' AS sys_audit_updated_by
FROM merchant_info a
LEFT JOIN existing_data b ON a.store_id = b.store_id