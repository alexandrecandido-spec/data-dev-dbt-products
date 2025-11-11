with base as (
  select
    m.store_id,
    m.mes,               
    st.first_payment,
    st.first_seller_at,
    st.churned_at,
    st.new_seller,
    core.created_at
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }} m
  left join {{ ref('s__lifecycle__store_status__ref') }} st
    on st.store_id = m.store_id
  left join {{ ref('s__attributes__store_core__ref') }} core
    on core.store_id = m.store_id
),
fl as (
  select store_id, mes, first_sale_date_all_time
  from {{ ref('_int__deepdive_gmv__first_last_and_flags') }}
)

select
  b.store_id,
  b.mes,

  -- Tenures (month-to-month + 1)
  cast(months_between(date_trunc('month', b.mes),
                      date_trunc('month', b.created_at)) as int) + 1      as months_from_creation,
  cast(months_between(date_trunc('month', b.mes),
                      date_trunc('month', b.first_payment)) as int) + 1   as months_from_first_payment,
  cast(months_between(date_trunc('month', b.mes),
                      date_trunc('month', b.first_seller_at)) as int) + 1 as months_from_first_seller,

  -- first_sale viene de la intermedia (join a fl)
  cast(months_between(date_trunc('month', b.mes),
                      date_trunc('month', f.first_sale_date_all_time)) as int) + 1
    as months_from_first_sale,

  -- months_from_new_seller (solo si new_seller=1 y hay first_seller_at)
  case when b.new_seller = true and b.first_seller_at is not null then
    cast(months_between(date_trunc('month', b.mes),
                        date_trunc('month', b.first_seller_at)) as int) + 1
  end as months_from_new_seller

from base b
left join fl f
  on f.store_id = b.store_id
 and f.mes      = b.mes
