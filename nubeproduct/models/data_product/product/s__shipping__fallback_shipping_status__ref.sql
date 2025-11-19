{{ config(
  materialized = 'incremental',
  incremental_strategy = 'merge',
  unique_key = ['store_id'],
  on_schema_change = 'fail',
  tags = ['daily-9am']
) }}

-- s__shipping__fallback_shipping_status__ref

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)


SELECT
    ss.store_id,
    sc.country_code as country,
    ss.current_plan_type as plan_group,
    ss.current_segment as segment,
    ss.state,
    CASE
        WHEN o.option_value IS NULL AND sc.country_code = 'AR' THEN FALSE
        WHEN o.option_value IS NULL AND sc.country_code <> 'AR' THEN TRUE
        WHEN o.option_value = '1' THEN TRUE
        ELSE FALSE
    END AS is_fallback_active,
    CASE
        WHEN ss.current_plan_type = 'freemium' THEN TRUE
        ELSE FALSE
    END AS is_freemium,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by


FROM {{ ref('s__lifecycle__store_status__ref') }} ss

JOIN {{ ref('s__attributes__store_core__ref') }} sc
    ON sc.store_id = ss.store_id

LEFT JOIN {{ ref('moltres__mwp_options') }} o
    ON o.store_id = ss.store_id
    AND o.option_name = 'fallback_shipping_available'

LEFT JOIN existing_data e
    ON e.store_id = ss.store_id


WHERE 1=1
    AND ss.churned_at is null
    AND ss.state in (0, 1, 2)

{% if is_incremental() %}
AND GREATEST(
    COALESCE(ss.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
    COALESCE(sc.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
    COALESCE(o.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), CAST('1900-01-01' AS TIMESTAMP)) FROM {{ this }}
)
{% endif %}