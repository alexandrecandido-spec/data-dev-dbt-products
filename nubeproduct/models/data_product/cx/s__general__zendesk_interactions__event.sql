{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['ticket_id','interaction_id'],
    on_schema_change='fail',
    tags=["daily-7am"]
  )
}}

{% if is_incremental() %}
  ,existing AS (select ticket_id, interaction_id, sys_audit_created_on, sys_audit_created_by from {{ this }})
{% else %}
  ,existing AS (select cast(null as bigint) as ticket_id, cast(null as bigint) as interaction_id, cast(null as timestamp) as sys_audit_created_on, cast(null as string) as sys_audit_created_by)
{% endif %}

SELECT
 a.ticket_id
,a.interaction_id
,a.interaction_timestamp
,a.author_id
,a.author_type
,a.interaction_type
,a.source
,a.is_bot_interaction
,a.ticket_interaction_rank
,a.interaction_group_id
,a.is_start_interaction_group
,a.is_end_interaction_group
,a.is_start_in_interaction
,a.previous_in_interaction_id
,a.previous_out_interaction_id
,a.previous_in_interaction_time
,a.previous_out_interaction_time
,a.assignee_id
,a.group_id
{% if is_incremental() %}
    ,COALESCE(b.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on
    ,COALESCE(b.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
{% else %}
    ,current_timestamp()     AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
{% endif %}
,current_timestamp       AS sys_audit_updated_on
,'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_cx__zendesk_interactions') }} a
LEFT JOIN existing b on a.ticket_id = b.ticket_id and a.interaction_id = b.interaction_id