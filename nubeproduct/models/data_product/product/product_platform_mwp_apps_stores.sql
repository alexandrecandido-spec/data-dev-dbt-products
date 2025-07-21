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
    where app_install_date is not null

),
deduped_installs AS (
    SELECT
        store_id,
        app_id,
        app_install_date,
        app_uninstall_date,
        ROW_NUMBER() OVER (PARTITION BY store_id, app_id, app_install_date ORDER BY app_uninstall_date DESC) as rn
    FROM installs
),
installs_clean AS (
    SELECT *
    FROM deduped_installs
    WHERE rn = 1
),
install_lag AS (
    SELECT 
        i.*,
        LAG(i.app_uninstall_date) OVER (PARTITION BY i.store_id, i.app_id ORDER BY i.app_install_date) AS prev_uninstall_date
    FROM installs_clean i
),
install_groups AS (
    SELECT 
        *,
        SUM(CASE WHEN prev_uninstall_date = app_install_date THEN 0 ELSE 1 END) 
            OVER (PARTITION BY store_id, app_id ORDER BY app_install_date 
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS install_group
    FROM install_lag
),
grouped AS (
    SELECT
        store_id,
        app_id,
        MIN(app_install_date) AS app_install_date,
        CASE WHEN MAX(app_uninstall_date) > current_date THEN null ELSE MAX(app_uninstall_date) END AS app_uninstall_date
    FROM install_groups
    GROUP BY store_id, app_id, install_group
),
final_groups AS (
    SELECT
        concat(cast(store_id as string), '_', cast(app_id as string), '_', cast(app_install_date as string)) as store_app_id,
        store_id,
        app_id,
        app_install_date,
        app_uninstall_date
    FROM grouped
),
deduped_final_groups AS (
    SELECT *
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY store_app_id ORDER BY app_install_date) as dedupe_rn
        FROM final_groups
    )
    WHERE dedupe_rn = 1
)
SELECT 
    dfg.store_app_id,
    dfg.store_id,
    dfg.app_id,
    dfg.app_install_date,
    dfg.app_uninstall_date,
    current_timestamp as sys_admin_created_at,
    'data-dev-dbt-products' as sys_admin_creatd_by,
    current_timestamp as sys_audit_updated_at
    'data-dev-dbt-products' as sys_admin_updated_by,
FROM deduped_final_groups dfg
        {% if is_incremental() %}
    WHERE 
        dfg.app_install_date >= (select coalesce(max(a.app_install_date),'1900-01-01') from {{ this }} a )
    {% endif %}