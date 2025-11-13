{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    unique_key           = ['store_id','year_month_code'],
    partition_by         = ['year_month_code'],
    cluster_by           = ['store_id'],
    on_schema_change     = 'fail',
    tags                 = ["daily-9am-9pm"]
) }}

with
/* ===========================
   1) Meses con cambios en DAILY
   =========================== */
{% if is_incremental() %}
dp_prev_max_daily as (
  select coalesce(max(sys_audit_month_max), timestamp '1900-01-01') as prev_global_daily_audit
  from {{ this }}
),
daily_changed as (
  select last_day(d.date) as reported_month
  from {{ ref('g__operations__orders_gmv_store__agg_daily') }} d
  where d.sys_audit_updated_on > (select prev_global_daily_audit from dp_prev_max_daily)
  group by 1
),
{% else %}
daily_changed as (
  select last_day(d.date) as reported_month
  from {{ ref('g__operations__orders_gmv_store__agg_daily') }} d
  group by 1
),
{% endif %}

/* ===========================================
   2) Audit de STATUS + CORE + MILESTONES
   =========================================== */
status_core_audit_now as (
  select
    st.store_id,
    {{ marketing_mpt_greatest_ts([
      'st.sys_audit_updated_on',
      'core.sys_audit_updated_on'
    ]) }} as status_core_audit_max_now
  from {{ ref('s__lifecycle__store_status__ref') }} st
  left join {{ ref('s__attributes__store_core__ref') }} core
    on core.store_id = st.store_id
),

milestones_audit_now as (
  select
    store_id,
    cast(sys_audit_updated_on as timestamp) as milestones_audit_max_now
  from {{ ref('s__lifecycle__store_sales_milestones__ref') }}
),

-- Audit unificado (mantenemos el alias que usa el DP aguas abajo)
status_audit_now as (
  select
    coalesce(sc.store_id, ms.store_id) as store_id,
    greatest(
      coalesce(sc.status_core_audit_max_now, timestamp '1900-01-01'),
      coalesce(ms.milestones_audit_max_now,  timestamp '1900-01-01')
    ) as status_audit_max_now
  from status_core_audit_now sc
  full outer join milestones_audit_now ms
    on ms.store_id = sc.store_id
),

/* ==================================================
   3) Stores cuyo audit aumentó vs lo ya persistido
   ================================================== */
{% if is_incremental() %}
dp_prev_status_audit as (
  select store_id, max(status_audit_max) as status_audit_max_prev
  from {{ this }}
  group by store_id
),
stores_changed_status as (
  select n.store_id
  from status_audit_now n
  left join dp_prev_status_audit p using (store_id)
  where p.status_audit_max_prev is null
     or n.status_audit_max_now > p.status_audit_max_prev
),
{% else %}
stores_changed_status as (
  select distinct store_id from status_audit_now
),
{% endif %}

/* ======================================================
   4) Meses a reescribir por cambio de status/core/milestones
   ====================================================== */
months_for_changed_stores as (
  {% if is_incremental() %}
    select c.reported_month
    from {{ ref('_int__deepdive_gmv__consolidated_monthly') }} c
    join stores_changed_status s using (store_id)
    group by c.reported_month

    union

    -- y meses ya existentes en el DP
    select d.reported_month
    from {{ this }} d
    join stores_changed_status s using (store_id)
    group by d.reported_month
  {% else %}
    -- full-refresh: meses que estén en la consolidada
    select c.reported_month
    from {{ ref('_int__deepdive_gmv__consolidated_monthly') }} c
    join stores_changed_status s using (store_id)
    group by c.reported_month
  {% endif %}
),

/* ===========================
   5) Siempre incluir el mes corriente
   =========================== */
current_month as (
  select last_day(current_date) as reported_month
),

/* =======================================================
   6) Particiones objetivo = daily ∪ status/core/milestones ∪ corriente
   ======================================================= */
months_to_overwrite as (
  select reported_month from daily_changed
  union
  select reported_month from months_for_changed_stores
  union
  select reported_month from current_month
),

/* ==========================================================
   7) Fuente consolidada filtrada a meses objetivo + YYYYMM + audit
   ========================================================== */
src_all as (
  select
    c.*,
    cast(date_format(c.reported_month, 'yyyyMM') as int) as year_month_code,
    san.status_audit_max_now
  from {{ ref('_int__deepdive_gmv__consolidated_monthly') }} c
  left join status_audit_now san using (store_id)
  join months_to_overwrite m using (reported_month)
),

/* ==================================================
   8) Hash del payload para trazabilidad del DP mensual
   ================================================== */
src as (
  select
    a.*,
    {{ marketing_mpt_hash([
      "a.store_id","a.reported_month",
      "a.gmv","a.gmv_usd","a.orders","a.product_quantity","a.avg_ticket","a.avg_ticket_usd",
      "a.orders_on_platform","a.orders_off_platform",
      "a.gmv_on_platform","a.gmv_off_platform",
      "a.gmv_usd_on_platform","a.gmv_usd_off_platform",
      "a.avg_gmv_last_3_months","a.avg_gmv_usd_last_3_months",
      "a.gmv_local_monthly_range","a.gmv_usd_monthly_range",
      "a.gmv_local_current_range","a.gmv_usd_current_range",
      "a.first_sale_date_all_time","a.first_sale_month_all_time",
      "a.last_sale_date","a.last_sale_month",
      "a.is_first_sale_month","a.is_last_sale_month",
      "a.gmv_new_vs_churned",
      "a.current_plan","a.current_bu","a.historical_plan","a.historical_bu","a.current_seller_segment",
      "a.months_from_creation","a.months_from_first_payment",
      "a.months_from_first_seller","a.months_from_first_sale","a.months_from_new_seller"
    ]) }} as row_hash
  from src_all a
),

/* ==========================================================
   9) Audit mensual máximo desde DAILY (para persistir en DP)
   ========================================================== */
month_audit as (
  select
    last_day(d.date)            as reported_month,
    max(d.sys_audit_updated_on) as sys_audit_month_max
  from {{ ref('g__operations__orders_gmv_store__agg_daily') }} d
  where last_day(d.date) in (select reported_month from months_to_overwrite)
  group by 1
)

{% if is_incremental() %}
, existing as (
  select store_id, year_month_code, sys_audit_created_on, sys_audit_created_by
  from {{ this }}
)
{% endif %}

/* ===========================
   10) SELECT final (proyección)
   =========================== */
select
  -- clave y partición
  s.store_id,
  s.reported_month,
  s.year_month_code,

  -- métricas núcleo
  s.gmv,
  s.gmv_usd,
  s.orders,
  s.product_quantity,
  s.avg_ticket,
  s.avg_ticket_usd,

  -- on/off platform
  s.orders_on_platform,
  s.orders_off_platform,
  s.gmv_on_platform,
  s.gmv_off_platform,
  s.gmv_usd_on_platform,
  s.gmv_usd_off_platform,

  -- promedios 3M cerrados
  s.avg_gmv_last_3_months,
  s.avg_gmv_usd_last_3_months,

  -- rangos
  s.gmv_local_monthly_range,
  s.gmv_usd_monthly_range,
  s.gmv_local_current_range,
  s.gmv_usd_current_range,

  -- first/last + flags
  s.first_sale_date_all_time,
  s.first_sale_month_all_time,
  s.last_sale_date,
  s.last_sale_month,
  s.is_first_sale_month,
  s.is_last_sale_month,

  -- clasificación
  s.gmv_new_vs_churned,

  -- nombres ORIGINALES de daily (no renombramos)
  s.current_plan,
  s.current_bu,
  s.historical_plan,
  s.historical_bu,
  s.current_seller_segment,

  -- tenures
  s.months_from_creation,
  s.months_from_first_payment,
  s.months_from_first_seller,
  s.months_from_first_sale,
  s.months_from_new_seller,

  -- audits
  ma.sys_audit_month_max,                   
  s.status_audit_max_now as status_audit_max,  

  -- fingerprint mensual
  s.row_hash,

  -- auditoría DP (preserva created_on/by en updates)
  {% if is_incremental() %}
    coalesce(e.sys_audit_created_on, current_timestamp) as sys_audit_created_on,
    coalesce(e.sys_audit_created_by, 'data-dev-dbt-products') as sys_audit_created_by,
  {% else %}
    current_timestamp as sys_audit_created_on,
    'data-dev-dbt-products' as sys_audit_created_by,
  {% endif %}
  current_timestamp as sys_audit_updated_on,
  'data-dev-dbt-products' as sys_audit_updated_by

from src s
left join month_audit ma using (reported_month)
{% if is_incremental() %}
left join existing e
  on e.store_id = s.store_id
 and e.year_month_code = s.year_month_code
{% endif %}
