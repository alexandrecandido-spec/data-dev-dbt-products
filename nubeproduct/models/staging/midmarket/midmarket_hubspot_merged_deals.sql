{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['operations','daily-6am']
) }}

with 
  exploded_deals as (
      select 
          d.deal_id as merged_deal_id,
          d.sys_audit_updated_on as audit_merged_updated_on,
          explode(split(d.merged_deal_ids, '; ')) as deal_id
      from {{ source('stg_third_party', 'midmarket_hubspot_deals') }} d
      where d.merged_deal_ids is not null 
        and d.merged_deal_ids != ''
  ),
  -- dedup
    exploded_ranked as (
      select
          ed.*,
          row_number() over (
              partition by cast(ed.deal_id as bigint)
              order by ed.audit_merged_updated_on desc, ed.merged_deal_id desc
          ) as rn
      from exploded_deals ed
  ),
  exploded_dedup as (
      select *
      from exploded_ranked
      where rn = 1
  ),
  -- source incremental
  source as (
      select
          cast(ed.deal_id as bigint) as deal_id,
          'merged' as deletion_type,
          ed.audit_merged_updated_on,
          cast(null as timestamp) as archived_at,
          d.pipeline,
          d.dealstage,
          d.hubspot_owner_id,
          d.createdate,
          d.closedate,
          d.last_modified_date
      from exploded_dedup ed
      left join {{ source('stg_third_party', 'midmarket_hubspot_deals') }} d
          on cast(ed.deal_id as bigint) = d.deal_id
      {% if is_incremental() %} 
      where ed.audit_merged_updated_on >= (
          select coalesce(max(t.sys_audit_updated_on),'1900-01-01')
          from {{ this }} t
      )
      {% endif %}
  ),
  -- existing data
  existing_data AS (
      {{ get_existing_data(this, ['deal_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
  )

select
    s.deal_id,
    s.deletion_type,
    s.archived_at,
    s.audit_merged_updated_on,
    s.pipeline,
    s.dealstage,
    s.hubspot_owner_id,
    s.createdate,
    s.closedate,
    s.last_modified_date,
    coalesce(e.sys_audit_created_on, current_timestamp) as sys_audit_created_on,
    coalesce(e.sys_audit_created_by, 'data-dev-dbt-products') as sys_audit_created_by,
    current_timestamp as sys_audit_updated_on,
    'data-dev-dbt-products' as sys_audit_updated_by
from source s
left join existing_data e on s.deal_id = e.deal_id