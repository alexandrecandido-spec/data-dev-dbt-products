
-- i__company_metrics__orders_gmv_store__agg_daily
-- Camada: intermediate
-- Objetivo: consolidar dimensões, tratamentos e métricas agregadas
--           por dia e por store (e demais dimensões), incluindo:
--           - plano vigente via snapshot diário (completed_at = date_plan)
--           - colunas de auditoria para o DP (sys_audit_day_max, checksum_day)

with base_orders as (
  select
      o.id,
      o.store_id,
      o.country,
      cast(coalesce(paid_at, coalesce(o.completed_at, o.created_at)) as date)                                   as date,
      o.year_month_day_code,
      last_day(coalesce(paid_at, coalesce(o.completed_at, o.created_at)))                              as mes,
      o.platform_type,
      o.storefront,
      case when o.storefront = 'mobile' then 'Mobile' else 'Desktop' end as device,
      coalesce(
        case 
          when o.payment_handler = 'mercado-pago' then 'mercadopago'
          when o.payment_handler = 'custom'       then 'pagos-personalizados'
          else o.payment_handler
        end, 'undefined'
      ) as payment_provider,
      coalesce(o.gateway_method, 'undefined')                         as payment_method,
      coalesce(o.shipping_method, 'undefined')                               as shipping_method,
      coalesce(o.shipping_province, 'Undefined Province')             as shipping_province,
      o.gateway_installments,
      -- métricas ao nível do pedido
      coalesce(o.total_in_local_currency, 0) as total_in_local_currency,
      coalesce(o.total_in_usd, 0) as total_in_usd,
      o.shipping_cost,
      o.product_quantity,
      -- metrics session data
      coalesce(o.source_name, 'No Source') as source_name,
      coalesce(o.source_group, 'No Source Group') as source_group,
      coalesce(o.google_subchannel, 'No Google Subchannel') as google_subchannel,
      coalesce(o.traffic_type, 'No Traffic Type') as traffic_type,
      coalesce(o.is_end_user, FALSE) as is_end_user,
      coalesce(o.visitor_country, 'No Visitor Country') as visitor_country,

      -- auditoria para incrementalidade no DP
      o.sys_audit_updated_on
  from {{ ref('s__orders__carts_orders_heads__events') }} o
  where flg_gmv = true
),

orders_plus_store_attributes as (
  select
      ops.*,
      mi.domain, 
      coalesce(mi.vertical_name,      'undefined')          as vertical, 
      coalesce(mi.state_name,    'Undefined Province') as province, 
      coalesce(mi.city_name,     'Undefined City')     as city, 
      coalesce(mi.region_name,   'Undefined Region')   as region, 
      coalesce(mi.business_size_name, 'Undefined')          as business_size      
  from base_orders ops
  left join {{ ref('s__attributes__store_core__ref') }} mi 
    on ops.store_id = mi.store_id
),

orders_plus_store_plan_group as (
  select
      ops.*,
      last_day(ops.date) as datemonth_order,
      mi.current_plan_type                                         as current_plan,  
      coalesce(mi.max_segment,   'Undefined')          as max_seller_segment,
      mi.current_segment as current_seller_segment,
      case when mi.current_plan_type = 'enterprise' then 'MM' else 'SMB' end as current_bu 
  from orders_plus_store_attributes ops
  left join {{ ref('s__lifecycle__store_status__ref') }} mi
    on ops.store_id = mi.store_id
    
),

-- Snapshot diário do plano vigente (sem transformações extras) --Isso será atualizado assim que os novos dataproducts de active merchant atualizar
plans_snapshot as (
  select
     cast(am.date as date)                     as date_plan,
     am.store_id,
     am.store_country                          as country,
     am.store_id_plan_country                  as plan_id,
     case when gp.grupo = 'enterprise' then 'MM' else 'SMB' end as historical_bu, 
     coalesce(gp.grupo, 'Undefined')           as historical_plan_group
  from {{ source('int_finance', 'active_merchants') }} am
  left join {{ ref('s__general__grouping_plans__ref') }} gp 
    on gp.plan = am.store_id_plan_country
)

, orders_with_historical_segment as (
  select
     ops.*,
     gs.segment as historical_seller_segment
  from orders_plus_store_plan_group ops 
  LEFT JOIN {{ ref('company_metrics_gmv_and_segments') }} gs
      on ops.store_id = gs.store_id
      and datemonth_order = gs.datemonth
)

  select
      s.id as order_id,
      s.store_id,
      s.country,
      s.domain,
      s.vertical,
      s.province,
      s.city,
      s.region,
      s.business_size,
      s.max_seller_segment,
      s.current_seller_segment,
      s.current_plan,
      coalesce(p.historical_plan_group, s.current_plan)  as historical_plan,  -- snapshot prevalece; MI é fallback
      coalesce(p.historical_bu, s.current_bu) as historical_bu,
      s.current_bu,
      s.historical_seller_segment,

      s.date,
      s.year_month_day_code,
      s.mes,
      s.platform_type,
      s.storefront,
      s.device,
      s.payment_provider,
      s.payment_method,
      s.shipping_method,
      s.shipping_province,
      s.gateway_installments,
      
      source_name,
      source_group,
      google_subchannel,
      traffic_type,
      is_end_user,
      visitor_country,

      s.total_in_local_currency,
      s.total_in_usd,
      s.shipping_cost,
      s.product_quantity,

      s.sys_audit_updated_on
      
  from orders_with_historical_segment s
  left join plans_snapshot p
    on p.store_id  = s.store_id
   and p.date_plan = s.date
