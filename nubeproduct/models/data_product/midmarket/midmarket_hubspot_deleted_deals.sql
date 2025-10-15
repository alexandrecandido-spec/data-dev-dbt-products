{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['operations','daily-6am']
) }}

with archived_deals as (
    select
        deal_id,
        deletion_type,
        archived_at,
        sys_audit_created_on,
        sys_audit_created_by,
        sys_audit_updated_on,
        sys_audit_updated_by
    from {{ ref('midmarket_hubspot_archived_deals') }}
    {% if is_incremental() %}
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

merged_deals as (
    select
        deal_id,
        deletion_type,
        archived_at,
        sys_audit_created_on,
        sys_audit_created_by,
        sys_audit_updated_on,
        sys_audit_updated_by
    from {{ ref('midmarket_hubspot_merged_deals') }}
    {% if is_incremental() %}
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data as (
    {{ get_existing_data(this, ['deal_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

unioned_deals as (
    select * from archived_deals
    union all
    select * from merged_deals
)

select 
    u.deal_id,
    u.deletion_type,
    u.archived_at,
    coalesce(e.sys_audit_created_on, u.sys_audit_created_on) as sys_audit_created_on,
    coalesce(e.sys_audit_created_by, u.sys_audit_created_by) as sys_audit_created_by,
    u.sys_audit_updated_on,
    u.sys_audit_updated_by
from unioned_deals u
left join existing_data e
    on u.deal_id = e.deal_id