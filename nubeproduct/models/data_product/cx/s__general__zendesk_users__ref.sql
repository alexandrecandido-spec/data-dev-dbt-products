{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['user_id'],
    on_schema_change='fail',
    tags=["cx","daily-6am"]
  )
}}

{% if is_incremental() %}
  ,existing AS (select user_id, sys_audit_created_on, sys_audit_created_by from {{ this }})
{% else %}
  ,existing AS (select cast(null as bigint) as user_id, cast(null as timestamp) as sys_audit_created_on, cast(null as string) as sys_audit_created_by)
{% endif %}

SELECT
 a.user_id
,a.name
,a.email
,a.role
,a.phone
,a.active
,a.created_at
,a.updated_at
,a.external_id
,a.iana_time_zone
,a.locale
,a.locale_id
,a.moderator
,a.only_private_comments
,a.organization_id
,a.report_csv
,a.restricted_agent
,a.shared
,a.shared_agent
,a.shared_phone_number
,a.suspended
,a.tags
,a.ticket_restriction
,a.time_zone
,a.url
,a.verified
,a.user_fields
,a.user_fields_agent_ooo
,a.user_fields_has_store
,a.user_fields_is_partner
,a.user_fields_no_recebe_e_mail
,a.user_fields_not_actually_a_partner
{% if is_incremental() %}
    ,COALESCE(b.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on
    ,COALESCE(b.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
{% else %}
    ,current_timestamp()     AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
{% endif %}
,current_timestamp       AS sys_audit_updated_on
,'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_cx__zendesk_users') }} a
LEFT JOIN existing b on a.user_id = b.user_id