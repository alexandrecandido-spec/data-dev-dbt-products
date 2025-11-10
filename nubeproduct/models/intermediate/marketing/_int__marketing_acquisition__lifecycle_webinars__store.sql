-- Intermediate EPHEMERAL | Project Webinars (store grain)
-- Fuente: staging marketing__product_marketing__lifecycle_registrados_webinars__event
-- Lógica: una fila por store_id con:
--   - has_wb_tag: 1 si asistió (status in ('live','on demand'))
--   - first_webinar_at: MIN(fecha de asistencia)
--   - deps_wb_updated_on: MAX(sys_audit_updated_on) para incrementalidad downstream


with wb_src as (
  select
    cast(store_id as bigint)                 as store_id,
    lower(trim(status))                      as status_norm,
    cast(webinar_date as date)               as webinar_date,
    cast(sys_audit_updated_on as timestamp)  as wb_row_updated_on
  from {{ ref('marketing__product_marketing__lifecycle_registrados_webinars__event') }}
  where store_id is not null
),

attended as (
  select *
  from wb_src
  where status_norm in ('live','on-demand')
    and webinar_date is not null
),

agg as (
  select
    store_id,
    min(webinar_date)      as first_webinar_at,
    max(wb_row_updated_on) as deps_wb_updated_on,
    count(*)               as attended_events
  from attended
  group by 1
)

select
  store_id,
  1                   as has_wb_tag,
  first_webinar_at,
  deps_wb_updated_on
from agg

