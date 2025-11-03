{{
    config(
        materialized='incremental',
        incremental_strategy = 'merge',
        unique_key=['ticket_id','event_id'],
        partition_by=['field_name','year_month_day_code'],
        on_schema_change='fail',
        tags=["cx","daily-6am"]
    )
}}

{% if is_incremental() %}

  WITH 
  source as 
  (
  SELECT ticket_id, event_timestamp, event_id, field_name, field_value
  FROM
  (
  SELECT
   ticket_id
  ,event_timestamp
  ,event_id
  ,field_name
  ,field_value
  ,row_number() over (partition by ticket_id, event_id order by event_timestamp desc) as rnk
  FROM  {{ ref('_int_cx__zendesk_tickets_events') }}
  WHERE airbyte_extracted_at >= (select coalesce(max(date(sys_audit_updated_on)), date('1900-01-01')) from {{ this }})
  )
  WHERE rnk = 1
  )
  ,existing as (select ticket_id, event_id, sys_audit_created_on, sys_audit_created_by from {{ this }})
 
  SELECT
   d.ticket_id
  ,d.event_timestamp
  ,d.event_id
  ,d.field_name
  ,d.field_value
  ,cast(date_format(d.event_timestamp, 'yyyyMMdd') as int)   AS year_month_day_code
  ,coalesce(e.sys_audit_created_on, current_timestamp())     AS sys_audit_created_on
  ,coalesce(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
  ,current_timestamp()                                       AS sys_audit_updated_on
  ,'data-dev-dbt-products'                                   AS sys_audit_updated_by
  FROM source d
  LEFT JOIN existing e on d.ticket_id = e.ticket_id and d.event_id  = e.event_id

{% else %}

  WITH
   source AS
  (
    SELECT ticket_id, event_timestamp, event_id, field_name, field_value 
    FROM {{ source('dp_zendesk_support_prod', 'legacy_ticket_history') }}
    WHERE field_name in ('status','group_id','assignee_id','satisfaction_score')
    UNION ALL
    SELECT ticket_id, event_timestamp, event_id, field_name, field_value 
    FROM {{ ref('_int_cx__zendesk_tickets_events') }}
  ),
  dedup as
  (
  SELECT ticket_id, event_timestamp, event_id, field_name, field_value
  FROM
  (
  SELECT
   ticket_id
  ,event_timestamp
  ,event_id
  ,field_name
  ,field_value
  ,row_number() over (PARTITION BY ticket_id, event_id ORDER BY event_timestamp DESC) AS rnk
  FROM source
  ) 
  WHERE rnk = 1
  )
  
  SELECT
   ticket_id
  ,event_timestamp
  ,event_id
  ,field_name
  ,field_value
  ,cast(date_format(event_timestamp, 'yyyyMMdd') as int) AS year_month_day_code
  ,current_timestamp()     AS sys_audit_created_on
  ,'data-dev-dbt-products' AS sys_audit_created_by
  ,current_timestamp()     AS sys_audit_updated_on
  ,'data-dev-dbt-products' AS sys_audit_updated_by
  FROM dedup

{% endif %}