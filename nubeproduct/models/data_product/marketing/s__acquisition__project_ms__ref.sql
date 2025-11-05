{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key=['store_id'],
  partition_by=['year_month_day_code'],
  on_schema_change='fail',
  tags=['daily-9am','marketing'],
  post_hook=["OPTIMIZE {{ this }} ZORDER BY (store_id, ms_contact_date)"]
) }}

-- 1) baseline para incremental
with baseline as (
  {% if is_incremental() %}
    select coalesce(max(sys_audit_updated_on), timestamp '1900-01-01') as last_upd
    from {{ this }}
  {% else %}
    select timestamp '1900-01-01' as last_upd
  {% endif %}
),

-- 2) fuente (ya viene SOLO con has_ms_tag=1 desde la intermediate)
src_all as (
  select *
  from {{ ref('_int__marketing_acquisition__project_ms__store') }}
),

-- 3) ids cambiados (lookback fijo)
{% set lookback = 7 %}
{{ marketing_mpt_changed_ids(
     last_upd_cte='baseline',
     lookback_days=lookback,
     sources=[
       {"sql": "select cast(store_id as bigint) store_id, max(sys_audit_updated_on) updated_on
                from " ~ ref('marketing__acquisition__project_ms_base__domain') ~ " group by 1"},
       {"sql": "select cast(store_id as bigint) store_id, sys_audit_updated_on as updated_on
                from " ~ ref('s__attributes__store_core__ref')},
       {"sql": "select cast(store_id as bigint) store_id, sys_audit_updated_on as updated_on
                from " ~ ref('s__lifecycle__store_status__ref')},
       {"sql": "select cast(store_id as bigint) store_id, max(sys_audit_updated_on) updated_on
                from " ~ ref('marketing_attribution_model') ~ " group by 1"}
     ]
) }}

, src as (
  {% if is_incremental() %}
    -- (a) nuevos que aún no existen en el target
    select s.*
    from src_all s
    left join {{ this }} t using (store_id)
    where t.store_id is null

    union all

    -- (b) y los que cambiaron según changed_ids
    select s.*
    from src_all s
    inner join changed_ids c using (store_id)
  {% else %}
    select * from src_all
  {% endif %}
)

-- 4) claves y partición
, with_keys as (
  select
    s.*,
    {{ marketing_mpt_greatest_ts([
      'deps_ms_updated_on',
      'deps_sc_updated_on',
      'deps_lc_updated_on',
      'deps_at_updated_on'
    ]) }} as deps_last_updated_on,

    coalesce(
      cast(ms_contact_date as date),
      cast(created_at as date),
      first_disparo_date,
      first_visit_date
    ) as partition_date,

    cast(date_format(
      coalesce(
        cast(ms_contact_date as date),
        cast(created_at as date),
        first_disparo_date,
        first_visit_date
      ), 'yyyyMMdd'
    ) as int) as year_month_day_code
  from src s
)

-- 5) existing (para preservar created_*)
, existing as (
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

-- 6) auditoría + row hash
, final_rows as (
  select
    w.*,
    coalesce(e.sys_audit_created_on, current_timestamp)         as sys_audit_created_on,
    coalesce(e.sys_audit_created_by,  'data-dev-dbt-marketing') as sys_audit_created_by,
    current_timestamp                                           as sys_audit_updated_on,
    'data-dev-dbt-marketing'                                    as sys_audit_updated_by,

    {{ mpt_hash([
      'w.store_id',
      'w.has_ms_tag',
      'w.ms_reason',
      'w.ms_contact_date',
      'w.created_at',
      'w.partner_code',
      'w.new_seller_at',
      'w.first_payment',
      'w.churned_at',
      'w.domain',
      'w.emails',
      'w.phones',
      'w.instagram_url',
      'w.platform',
      'w.estimated_monthly_sales',
      'w.peso',
      'w.repeated_domain',
      'w.disparos',
      'w.disparo_date',
      'w.mapping_method',
      'w.first_disparo_date',
      'w.first_visit_ts',
      'w.first_visit_date',
      'w.deps_ms_updated_on',
      'w.deps_sc_updated_on',
      'w.deps_lc_updated_on',
      'w.deps_at_updated_on',
      'w.deps_last_updated_on',
      'w.year_month_day_code'
    ]) }} as row_hash
  from with_keys w
  left join existing e using (store_id)
)

-- 7) fuente del MERGE
select * from final_rows