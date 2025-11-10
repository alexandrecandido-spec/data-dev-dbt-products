-- _int__marketing_acquisition__project_tags__store.sql
-- EPHEMERAL

with ms as (
  select store_id, has_ms_tag, ms_contact_date,
         deps_ms_updated_on, deps_sc_updated_on, deps_lc_updated_on, deps_at_updated_on
  from {{ ref('_int__marketing_acquisition__project_ms__store') }}
),
ds as (
  select store_id, has_ds_tag, ds_tag_created_date, deps_ds_updated_on
  from {{ ref('_int__marketing_acquisition__project_ds__store') }}
),
wb as (
  select store_id, has_wb_tag, first_webinar_at, deps_wb_updated_on
  from {{ ref('_int__marketing_acquisition__lifecycle_webinars__store') }}
),
keys as (
  select store_id from ms
  union
  select store_id from ds
  union
  select store_id from wb
),
joined as (
  select
    k.store_id,
    coalesce(ms.has_ms_tag,0) as has_ms_tag,
    coalesce(ds.has_ds_tag,0) as has_ds_tag,
    coalesce(wb.has_wb_tag,0) as has_wb_tag,

    case when coalesce(ms.has_ms_tag,0)=1 then 'Merchant Sellers' end as tag_ms_name,
    case when coalesce(ds.has_ds_tag,0)=1 then 'Drop Sellers'     end as tag_ds_name,
    case when coalesce(wb.has_wb_tag,0)=1
         then concat('Webinars ', date_format(wb.first_webinar_at,'MM-yy')) end as tag_wb_name,

    ms.ms_contact_date,
    ds.ds_tag_created_date,
    wb.first_webinar_at,

    ms.deps_ms_updated_on, ms.deps_sc_updated_on, ms.deps_lc_updated_on, ms.deps_at_updated_on,
    ds.deps_ds_updated_on,
    wb.deps_wb_updated_on
  from keys k
  left join ms on ms.store_id = k.store_id
  left join ds on ds.store_id = k.store_id
  left join wb on wb.store_id = k.store_id
),
with_deps as (
  select
    j.*,
    {{ marketing_mpt_greatest_ts([
      'j.deps_ms_updated_on','j.deps_sc_updated_on','j.deps_lc_updated_on','j.deps_at_updated_on',
      'j.deps_ds_updated_on','j.deps_wb_updated_on'
    ]) }} as last_upd
  from joined j
)
select
  store_id,
  has_ms_tag, has_ds_tag, has_wb_tag,
  tag_ms_name, tag_ds_name, tag_wb_name,
  ms_contact_date, ds_tag_created_date, first_webinar_at,
  concat_ws(' + ', tag_ms_name, tag_ds_name, tag_wb_name) as marketing_projects_tag,
  last_upd
from with_deps
where coalesce(has_ms_tag,0)=1
   or coalesce(has_ds_tag,0)=1
   or coalesce(has_wb_tag,0)=1
