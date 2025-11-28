{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['ticket_id','subtopic_raw'],
    on_schema_change='fail',
    tags=["daily-7am"]
  )
}}

{% if is_incremental() %}
  ,existing AS (select ticket_id, subtopic_raw, sys_audit_created_on, sys_audit_created_by from {{ this }})
{% else %}
  ,existing AS (select cast(null as bigint) as ticket_id, cast(null as string) as subtopic_raw, cast(null as timestamp) as sys_audit_created_on, cast(null as string) as sys_audit_created_by)
{% endif %}

SELECT
 a.ticket_id
,a.created_at
,a.main_topic_normalized
,a.secondary_topic_normalized
,a.subtopic_normalized
,a.subtopic_raw
{% if is_incremental() %}
    ,COALESCE(b.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on
    ,COALESCE(b.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
{% else %}
    ,current_timestamp()     AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
{% endif %}
,current_timestamp       AS sys_audit_updated_on
,'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_cx__zendesk_ticket_topics') }} a
LEFT JOIN existing b on a.ticket_id = b.ticket_id and a.subtopic_raw = b.subtopic_raw