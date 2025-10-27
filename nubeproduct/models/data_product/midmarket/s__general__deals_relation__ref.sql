{{ config(
  materialized='table',          -- se sobreescribe a diario
  on_schema_change='fail',
  tags=['daily-6am']
) }}

select distinct
  from_deal_id,
  from_pipeline,
  from_dealstage,
  from_createdate,
  to_deal_id,
  to_pipeline,
  to_dealstage,
  to_createdate,
  current_timestamp as sys_audit_created_on,
  'data-dev-dbt-products' as sys_audit_created_by,
  current_timestamp as sys_audit_updated_on,
  'data-dev-dbt-products' as sys_audit_updated_by
from {{ ref('_int_midmarket__deals_relation') }};
