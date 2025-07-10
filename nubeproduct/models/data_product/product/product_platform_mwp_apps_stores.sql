{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'store_app_id',
    partition_by = 'app_install_date',
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with
installs AS (
    SELECT  
      *
    FROM {{ ref('moltres__platform_mwp_apps_stores') }}

),
install_lag AS (
    SELECT 
        i.*,
        LAG(i.app_uninstall_date) OVER (PARTITION BY i.store_id, i.app_id ORDER BY i.app_install_date) AS prev_uninstall_date
    FROM installs i
),
install_groups AS (
    SELECT 
        *,
        SUM(CASE WHEN prev_uninstall_date = app_install_date THEN 0 ELSE 1 END) 
            OVER (PARTITION BY store_id, app_id ORDER BY app_install_date 
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS install_group
    FROM install_lag
),
final_groups AS (
    SELECT
        concat(cast(store_id as string), '_', cast(app_id as string), '_', cast(MIN(app_install_date) as string)) as store_app_id,
        store_id,
        app_id,
        MIN(app_install_date) AS app_install_date,
        CASE WHEN MAX(app_uninstall_date) > current_date THEN null ELSE MAX(app_uninstall_date) END AS app_uninstall_date
    FROM install_groups
    GROUP BY store_id, app_id, install_group
)
SELECT 
    fg.store_app_id,
    fg.store_id,
    fg.app_id,
    fg.app_install_date,
    fg.app_uninstall_date,
    -- Set created_at only for new records, updated_at always
    {% if is_incremental() %}
        COALESCE(target.sys_admin_created_at, current_timestamp) as sys_admin_created_at,
    {% else %}
        current_timestamp as sys_admin_created_at,
    {% endif %}
    current_timestamp as sys_audit_updated_at
FROM final_groups fg
-- For merge strategy, join to target to get existing created_at
{% if is_incremental() %}
LEFT JOIN {{ this }} target
    ON fg.store_app_id = target.store_app_id
{% endif %}