{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key='store_id',
  partition_by=['year_month_day_code'],
  on_schema_change='fail',
  tags=['daily-9am','marketing'],
  zorder_by=['store_id']
) }}

--- 1) Fuente: solo stores con al menos una tag
with base as (
  select
      t.store_id,

      -- booleans
      t.has_ms_tag,
      t.has_ds_tag,
      t.has_wb_tag,

      -- nombres de tag
      t.tag_ms_name,
      t.tag_ds_name,
      t.tag_wb_name,

      -- fechas provenientes del rollup
      t.ms_contact_date,
      t.ds_tag_created_date,       
      t.first_webinar_at,

      -- concat final
      t.marketing_projects_tag,

      -- timestamp de cambio en la intermediate 
      cast(t.last_upd as timestamp) as updated_at
  from {{ ref('_int__marketing_acquisition__project_tags__store') }} t
  where t.has_ms_tag = 1 or t.has_ds_tag = 1 or t.has_wb_tag = 1
),

-- 2) Proyección + partición + hash
projected as (
  select
      b.store_id,

      -- booleans normalizados a 0/1
      cast(b.has_ms_tag as int) as has_ms_tag,
      cast(b.has_ds_tag as int) as has_ds_tag,
      cast(b.has_wb_tag as int) as has_wb_tag,

      -- nombres de tag
      b.tag_ms_name,
      b.tag_ds_name,
      b.tag_wb_name,

      -- fechas expuestas
      cast(b.ms_contact_date     as date) as ms_contact_date,
      cast(b.ds_tag_created_date as date) as ds_tag_created_date,
      cast(b.first_webinar_at    as date) as first_webinar_at,

      -- concatenación final visible
      b.marketing_projects_tag,

      -- partición: primera fecha disponible (fallback = hoy)
      cast(
        date_format(
          coalesce(
            cast(b.ds_tag_created_date as date),
            cast(b.first_webinar_at    as date),
            cast(b.ms_contact_date     as date),
            current_date
          ),
          'yyyyMMdd'
        ) as int
      ) as year_month_day_code,

      -- auditoría (created_* se preserva abajo)
      current_timestamp                 as sys_audit_updated_on,
      'data-dev-dbt-marketing'          as sys_audit_updated_by,

      -- hash de contenido visible 
      {{ mpt_hash([
        "cast(b.has_ms_tag as string)",
        "cast(b.has_ds_tag as string)",
        "cast(b.has_wb_tag as string)",
        "b.tag_ms_name",
        "b.tag_ds_name",
        "b.tag_wb_name",
        "cast(b.ms_contact_date as string)",
        "cast(b.ds_tag_created_date as string)",
        "cast(b.first_webinar_at as string)",
        "b.marketing_projects_tag"
      ]) }} as row_hash
  from base b
),

-- 3) En incrementales, solo upsert de nuevos o cambiados (por hash)
to_upsert as (
  select p.*
  from projected p
  {% if is_incremental() %}
    left join {{ this }} t
      on t.store_id = p.store_id
   where t.store_id is null or t.row_hash <> p.row_hash
  {% endif %}
),

-- 4) Preservar created_* si la fila ya existía
existing as (
  {% if is_incremental() %}
    select store_id, sys_audit_created_on, sys_audit_created_by
    from {{ this }}
  {% else %}
    select
      cast(null as bigint)     as store_id,
      cast(null as timestamp)  as sys_audit_created_on,
      cast(null as string)     as sys_audit_created_by
    where 1=0
  {% endif %}
)

select
    u.store_id,
    u.has_ms_tag, u.has_ds_tag, u.has_wb_tag,
    u.tag_ms_name, u.tag_ds_name, u.tag_wb_name,
    u.ms_contact_date, u.ds_tag_created_date, u.first_webinar_at,
    u.marketing_projects_tag,
    u.year_month_day_code,
    coalesce(e.sys_audit_created_on, current_timestamp)         as sys_audit_created_on,
    coalesce(e.sys_audit_created_by,  'data-dev-dbt-marketing') as sys_audit_created_by,
    u.sys_audit_updated_on,
    u.sys_audit_updated_by,
    u.row_hash
from to_upsert u
left join existing e using (store_id)
