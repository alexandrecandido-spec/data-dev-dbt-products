-- Intermediate EPHEMERAL | Project DropSellers (store grain)
-- Señal exacta: presencia del tag 'project-dropsellers' en mwp_tags (type='store').
-- Incluye fecha del tag (created) y timestamp de auditoría para incrementalidad downstream.

with tags_raw as (
  select
      cast(related_id as bigint)               as store_id,
      cast(created as timestamp)               as created_ts,              
      cast(sys_audit_updated_on as timestamp)  as sys_upd                 
  from {{ source('int_moltres', 'mwp_tags') }}
  where lower(coalesce(type, '')) = 'store'
    and tag = 'project-dropsellers'
    and related_id is not null
),

ds_per_store as (
  select
      store_id,
      1 as has_ds_tag,
      min(created_ts) as ds_tag_created_at,
      -- Para incremental del DP: el “último update” visto arriba (sirve para detectar cambios)
      max(sys_upd)    as deps_ds_updated_on
  from tags_raw
  group by 1
)

select
    store_id,
    has_ds_tag,
    cast(ds_tag_created_at as date)            as ds_tag_created_date, 
    deps_ds_updated_on
from ds_per_store
