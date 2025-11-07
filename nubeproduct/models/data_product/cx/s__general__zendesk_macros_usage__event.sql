{{
    config(
        materialized='incremental',
        incremental_strategy = 'merge',
        unique_key=['ticket_id','macro_id','audit_id'],
        partition_by=['year_month_day_code'],
        on_schema_change='fail',
        tags=["cx","daily-6am"]
    )
}}

{% if is_incremental() %}

  WITH 
  source as 
  (
  SELECT ticket_id, audit_id, author_id, macro_id, created_at
  FROM
  (
  SELECT
   ticket_id
  ,audit_id
  ,author_id
  ,macro_id
  ,created_at
  ,row_number() over (partition by ticket_id, macro_id, audit_id order by created_at desc) as rnk
  FROM  {{ ref('_int_cx__zendesk_macros_usage') }}
  WHERE airbyte_extracted_at >= (select coalesce(max(date(sys_audit_updated_on)), date('1900-01-01')) from {{ this }})
  )
  WHERE rnk = 1
  )
  ,existing as (select ticket_id, macro_id, audit_id, sys_audit_created_on, sys_audit_created_by from {{ this }})
 
  SELECT
   d.ticket_id
  ,d.audit_id
  ,d.author_id
  ,d.macro_id
  ,d.created_at
  ,cast(date_format(d.created_at, 'yyyyMMdd') as int)        AS year_month_day_code
  ,coalesce(e.sys_audit_created_on, current_timestamp())     AS sys_audit_created_on
  ,coalesce(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
  ,current_timestamp()                                       AS sys_audit_updated_on
  ,'data-dev-dbt-products'                                   AS sys_audit_updated_by
  FROM source d
  LEFT JOIN existing e on d.ticket_id = e.ticket_id and d.macro_id  = e.macro_id and d.audit_id  = e.audit_id

{% else %}

  WITH
   source AS
  (
    SELECT ticket_id, audit_id, author_id, macro_id, created_at 
    FROM {{ source('dp_zendesk_support_prod', 'legacy_macros_usage') }}
    UNION ALL
    SELECT ticket_id, audit_id, author_id, macro_id, created_at 
    FROM {{ ref('_int_cx__zendesk_macros_usage') }}
  ),
  dedup as
  (
  SELECT ticket_id, audit_id, author_id, macro_id, created_at
  FROM
  (
  SELECT
   ticket_id
  ,audit_id
  ,author_id
  ,macro_id
  ,created_at
  ,row_number() over (partition by ticket_id, macro_id, audit_id order by created_at desc) as rnk
  FROM source
  ) 
  WHERE rnk = 1
  )
  
  SELECT
   ticket_id
  ,audit_id
  ,author_id
  ,macro_id
  ,created_at
  ,cast(date_format(created_at, 'yyyyMMdd') as int) AS year_month_day_code
  ,current_timestamp()     AS sys_audit_created_on
  ,'data-dev-dbt-products' AS sys_audit_created_by
  ,current_timestamp()     AS sys_audit_updated_on
  ,'data-dev-dbt-products' AS sys_audit_updated_by
  FROM dedup

{% endif %}