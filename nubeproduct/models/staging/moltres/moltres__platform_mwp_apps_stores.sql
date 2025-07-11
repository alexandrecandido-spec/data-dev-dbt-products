{{
    config(
        materialized='incremental',
        unique_key=['installed_app_id'],
        incremental_strategy='merge',
        on_schema_change='fail',
        tags=["product","daily-8am"]
    )
}}

SELECT DISTINCT 
    app_id
    ,store_id
    ,id AS installed_app_id
    ,date(created_at) AS app_install_date
    ,coalesce(date(deleted_at), date('2100-01-01')) AS app_uninstall_date
    ,current_timestamp as sys_admin_created_at
    ,current_timestamp as sys_audit_updated_at
from {{ source('stg_moltres', 'mwp_apps_stores') }} l
WHERE TRUE
and created_at is not null
{% if is_incremental() %}
and created_at >= (select coalesce(max(j.sys_audit_updated_at),'1900-01-01') from {{ this }} j)
{% endif %}