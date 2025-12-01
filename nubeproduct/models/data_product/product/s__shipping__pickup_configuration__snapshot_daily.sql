{{ config(
  materialized = 'incremental',
  incremental_strategy = 'merge',
  unique_key = ['store_id', 'pickup_feature', 'is_deleted', 'max_km', 'max_days_pickup'],
  on_schema_change = 'fail',
  tags = ['daily-9am']
) }}

-- s__shipping__pickup_configuration__snapshot_daily

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'pickup_feature', 'is_deleted', 'max_km', 'max_days_pickup', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)


SELECT
    ss.store_id,
    sc.domain,
    sc.country_code as country,
    ss.current_plan_type as plan_group,
    ss.current_segment as segment,
    sc.vertical_name as vertical,
    ss.state,
    CASE
        WHEN ss.churned_at IS NULL THEN FALSE
        ELSE TRUE
    END AS is_churned,
    CASE WHEN pf.pickup_feature IS NULL THEN 'none' ELSE pf.pickup_feature END AS pickup_feature,
    CASE WHEN pf.is_deleted IS NULL THEN FALSE ELSE pf.is_deleted END AS is_deleted,
    CASE WHEN pf.max_km IS NULL THEN 0 ELSE pf.max_km END AS max_km,
    CASE WHEN pf.max_days_pickup IS NULL THEN 0 ELSE pf.max_days_pickup END AS max_days_pickup,
    CASE WHEN pf.pickup_locations_count IS NULL THEN 0 ELSE pf.pickup_locations_count END AS pickup_locations_count,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by


FROM {{ ref('s__lifecycle__store_status__ref') }} ss

JOIN {{ ref('s__attributes__store_core__ref') }} sc
    ON sc.store_id = ss.store_id

LEFT JOIN {{ ref('_int__product__shipping__pickup_features') }} pf
    ON pf.store_id = ss.store_id

LEFT JOIN existing_data e
    ON e.store_id = ss.store_id
    AND e.pickup_feature = pf.pickup_feature
    AND e.is_deleted = pf.is_deleted
    AND e.max_km = pf.max_km
    AND e.max_days_pickup = pf.max_days_pickup

WHERE 1=1
    AND ss.state <> 4