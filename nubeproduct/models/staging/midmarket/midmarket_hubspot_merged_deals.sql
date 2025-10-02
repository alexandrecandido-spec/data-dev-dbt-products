{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['operations','daily-6am']
) }}

with 
  exploded_deals as (
      SELECT 
        d.deal_id as merged_deal_id,
        d.sys_audit_updated_on as audit_merged_updated_on,
        explode(split(d.merged_deal_ids, '; ')) AS deal_id
      FROM {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
      WHERE 
        d.merged_deal_ids IS NOT NULL 
        AND d.merged_deal_ids != ''
      ),
  source as (
      SELECT
        CAST(ed.deal_id AS BIGINT) AS deal_id,
        'merged' AS deletion_type,
        ed.audit_merged_updated_on,
        cast(null as timestamp) as archived_at,
        d.pipeline,
        d.dealstage,
        d.hubspot_owner_id,
        d.createdate,
        d.closedate,
        d.last_modified_date
      from exploded_deals as ed
        left join {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
          on CAST(ed.deal_id AS BIGINT) = d.deal_id
        {% if is_incremental() %} 
        WHERE 
          ed.audit_merged_updated_on >= (select coalesce(max(t.sys_audit_updated_on),'1900-01-01') from {{ this }} t)
        {% endif %}
      ),
  existing_data AS (
      {{ get_existing_data(this, ['deal_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
  )

SELECT 
    source.deal_id,
    source.deletion_type,
    source.archived_at,
    source.audit_merged_updated_on,
    source.pipeline,
    source.dealstage,
    source.hubspot_owner_id,
    source.createdate,
    source.closedate,
    source.last_modified_date,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
  LEFT JOIN existing_data e
      ON source.deal_id = e.deal_id