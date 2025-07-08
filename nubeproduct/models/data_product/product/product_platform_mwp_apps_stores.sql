{{ config(
    materialized = 'incremental',
    incremental_strategy='append',
    unique_key = 'store_app_id',
    partition_by = 'app_install_date',
    on_schema_change = 'fail',
    tags = ['platform','daily-8am']
) }}

with
installs AS (
    SELECT  
      *
    FROM {{ref('moltres__platform_mwp_apps_stores')}} 
),
install_lag AS (
    -- Obtener la fecha de desinstalación previa para detectar instalaciones consecutivas
    SELECT 
        i.*,
        LAG(i.app_uninstall_date) OVER (PARTITION BY i.store_id, i.app_id ORDER BY i.app_install_date) AS prev_uninstall_date
    FROM installs i
),
install_groups AS (
    -- Asignar un grupo distinto si la instalación no sigue inmediatamente a la desinstalación anterior
    SELECT 
        *,
        SUM(CASE WHEN prev_uninstall_date = app_install_date THEN 0 ELSE 1 END) 
            OVER (PARTITION BY store_id, app_id ORDER BY app_install_date 
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS install_group
    FROM install_lag
)
    -- Consolidar períodos de instalación en una sola fila
    SELECT 
        concat(cast(store_id as varchar),cast(app_id as varchar)) as store_app_id
        store_id
        ,app_id
        ,MIN(app_install_date) AS app_install_date
        ,case when MAX(app_uninstall_date) > current_date then null else MAX(app_uninstall_date) end AS app_uninstall_date
        ,max(sys_admin_created_at) as sys_admin_created_at
        ,max(sys_audit_updated_at) as sys_audit_updated_at
    FROM install_groups
    GROUP BY 1,2,3