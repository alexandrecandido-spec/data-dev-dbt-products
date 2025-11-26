{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['actor_id','actor_type','audit_id','timestamp','ticket_id'],
    on_schema_change='fail',
    tags=["daily-6am"]
  )
}}

 WITH

  source AS
 (
  SELECT
   actor_id
  ,actor_type
  ,audit_id
  ,timestamp
  ,ticket_id
  FROM {{ ref('_int_cx__zendesk_chats') }}
  {% if is_incremental() %}
    WHERE airbyte_extracted_at >= (SELECT coalesce(max(date(sys_audit_updated_on)), date('1900-01-01')) FROM {{ this }})
  {% endif %}
  )

 ,target AS 
 (
  SELECT
   actor_id
  ,actor_type
  ,audit_id
  ,timestamp
  ,ticket_id
  {% if is_incremental() %}
   ,sys_audit_created_on
   ,sys_audit_created_by
    FROM {{ this }}
    WHERE ticket_id IN (SELECT DISTINCT ticket_id FROM source)
  {% else %}
    FROM {{ source('dp_zendesk_support_prod', 'legacy_chats') }}
  {% endif %}
  )

 ,united AS
 (
  SELECT
  actor_id,
  actor_type,
  audit_id,
  date_format(timestamp, 'yyyy-MM-dd HH:mm:ss.SSS') AS timestamp,
  ticket_id
  FROM source

  UNION ALL

  SELECT
  actor_id,
  actor_type,
  audit_id,
  date_format(timestamp, 'yyyy-MM-dd HH:mm:ss.SSS') AS timestamp,
  ticket_id
  FROM target
 )
 ,dedup AS
 (
  SELECT actor_id, actor_type, audit_id, timestamp, ticket_id FROM
  (
   SELECT
   actor_id,
   actor_type,
   audit_id,
   timestamp,
   ticket_id,
   row_number() over (PARTITION BY actor_id, actor_type, audit_id, timestamp, ticket_id ORDER BY timestamp DESC) AS rnk
   FROM united
  ) WHERE rnk = 1
 )
  SELECT
   a.actor_id
  ,a.actor_type
  ,a.audit_id
  ,ROW_NUMBER() OVER (PARTITION BY a.ticket_id ORDER BY a.timestamp ASC, a.audit_id ASC) - 1 AS index
  ,date_format(a.timestamp, 'yyyy-MM-dd HH:mm:ss.SSS') AS timestamp
  ,a.ticket_id
  {% if is_incremental() %}
    ,COALESCE(b.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on
    ,COALESCE(b.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
  {% else %}
    ,current_timestamp()     AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
  {% endif %}
  ,current_timestamp AS sys_audit_updated_on
  ,'data-dev-dbt-products' AS sys_audit_updated_by
  FROM dedup a
  {% if is_incremental() %}
    LEFT JOIN target b on 
    COALESCE(a.actor_id,-1) = COALESCE(b.actor_id,-1) AND
    COALESCE(a.actor_type,'.') = COALESCE(b.actor_type,'.') AND
    COALESCE(a.audit_id,-1) = COALESCE(b.audit_id,-1) AND
    COALESCE(a.timestamp,to_timestamp('1900-01-01 00:00:00')) = COALESCE(b.timestamp,to_timestamp('1900-01-01 00:00:00')) AND
    COALESCE(a.ticket_id,-1) = COALESCE(b.ticket_id,-1)
  {% endif %}
