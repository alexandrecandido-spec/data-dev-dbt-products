{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=['daily-9am']
    )
}}
--feature_current_state
 with feature AS (
 SELECT
 store_id ,
 active,
 sys_audit_updated_on
 FROM
 {{source('dp_moltres', 'mwp_email_templates_v2')}}
 WHERE
 type = 'orderreadyforpickup' 
 ),

--feature_history
 history AS (
 SELECT
 store_id,
 date_add(min(report_date),-1) as first_active_at,
 date_add(max(report_date),-1) as last_active_at,
 max(sys_audit_updated_on) as sys_audit_updated_on
 FROM
{{ref('s__orders__ready_for_pickup_template_usage__snapshot_daily')}} u--only stores active on the day of the report show up here
 GROUP BY 1
 )

 SELECT 
 f.store_id,
 i.domain,
 i.current_segment,
 i.state,
 date(i.created_at) merchant_created_at,--only merchants created before 2025-08-06 have the choice to active template. Others are originated with it enabled.
 f.active currently_active,
first_active_at,
last_active_at,
'data-dev-dbt-products' AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
 FROM feature f
 left join {{ref('moltres__mwp_store_info')}} i ON f.store_id = i.store_id
 LEFT JOIN history h ON h.store_id = f.store_id 
   {% if is_incremental() %}
where f.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
or h.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}