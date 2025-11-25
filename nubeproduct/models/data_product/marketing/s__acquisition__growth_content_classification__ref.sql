{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key=['full_url_normalized'],
  on_schema_change='fail',
  tags=['daily-8am'],
  post_hook=["OPTIMIZE {{ this }} ZORDER BY (full_url_normalized)"]
) }}

with src_data as (
    select 
        full_url_normalized,
        full_url,
        title,
        funnel_stage,
        estimated_persona,
        category,
        focus_keyword,
        local_or_regional,
        downloadable_format,
        tool_name,
        source_origin
    from {{ ref('_int__acquisition__growth_content_classification') }}
),

src_with_hash as (
    select
        *,
        {{ marketing_mpt_hash([
            'title',
            'funnel_stage',
            'estimated_persona',
            'category',
            'focus_keyword',
            'local_or_regional',
            'downloadable_format',
            'tool_name',
            'source_origin'
        ]) }} as row_hash
    from src_data
),

existing as (
  {% if is_incremental() %}
    select 
        full_url_normalized, 
        sys_audit_created_on, 
        sys_audit_created_by,
        row_hash as current_hash
    from {{ this }}
  {% else %}
    select
        cast(null as string) as full_url_normalized,
        cast(null as timestamp) as sys_audit_created_on,
        cast(null as string) as sys_audit_created_by,
        cast(null as string) as current_hash
    where 1=0
  {% endif %}
)

select
    s.full_url_normalized,
    s.full_url,
    s.title,
    s.funnel_stage,
    s.estimated_persona,
    s.category,
    s.focus_keyword,
    s.local_or_regional,
    s.downloadable_format,
    s.tool_name,
    s.source_origin,
    s.row_hash,

    coalesce(e.sys_audit_created_on, current_timestamp()) as sys_audit_created_on,
    coalesce(e.sys_audit_created_by, 'data-dev-dbt-marketing') as sys_audit_created_by,
    current_timestamp() as sys_audit_updated_on,
    'data-dev-dbt-marketing' as sys_audit_updated_by

from src_with_hash s
left join existing e using (full_url_normalized)

{% if is_incremental() %}
    where e.full_url_normalized is null 
       or s.row_hash != e.current_hash
{% endif %}