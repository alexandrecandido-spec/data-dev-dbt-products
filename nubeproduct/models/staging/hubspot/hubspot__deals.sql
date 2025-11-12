{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'], 
    tags=['midmarket','daily-6am']
) }}

select
  id as deal_id,
  companies,

  current_timestamp AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

from {{ source('stg_hubspot','deals') }}