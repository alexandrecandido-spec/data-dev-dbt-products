
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
      cast(o.completed_at as date)                                   as date,
      cast(date_format(o.completed_at, 'yyyyMMdd') as integer)         as year_month_day_code,
      last_day(o.completed_at)                              as mes,
      o.platform_type,
      o.storefront,
      case when o.storefront = 'mobile' then 'Mobile' else 'Desktop' end as device,
      coalesce(
        case 
          when o.payment = 'mercado-pago' then 'mercadopago'
          when o.payment = 'custom'       then 'pagos-personalizados'
          else o.payment
        end, 'undefined'
      ) as payment_provider,
      coalesce(o.gateway_method, 'undefined')                         as payment_method,
      coalesce(o.shipping, 'undefined')                               as shipping_method,
      coalesce(o.shipping_province, 'Undefined Province')             as shipping_province,
      o.gateway_installments,
      -- métricas ao nível do pedido
      o.total,
      o.total_in_usd,
      o.shipping_cost,
      o.product_quantity,
      -- auditoria para incrementalidade no DP
      o.sys_audit_updated_on
  from {{ ref('company_metrics_paid_orders') }} o
),

orders_plus_source as (
  select
      bo.*,
      coalesce(os.source, 'No Source')               as order_source,
      coalesce(os.source_name, 'Sin Source Details') as social_network,
      os.source_details,
      os.source_type
  from base_orders bo
  left join {{ ref('product_social_order_source') }} os
    on bo.id = os.order_id
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
  from orders_plus_source ops
  left join {{ ref('s__attributes__store_core__ref') }} mi 
    on ops.store_id = mi.store_id
),

orders_plus_store_plan_group as (
  select
      ops.*,
      mi.current_plan_type                                         as nice_9_name,  
      mi.current_plan_type                                         as plan_group_mi, 
      coalesce(mi.max_segment,   'Undefined')          as segment,
      case when mi.current_plan_type = 'enterprise' then 'MM' else 'SMB' end as bu 
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
     gp.plan                                   as plan_code,
     coalesce(gp.grupo, 'Undefined')           as plan_group
  from {{ source('int_finance', 'active_merchants') }} am
  left join {{ ref('s__general__grouping_plans__ref') }} gp 
    on gp.plan = am.store_id_plan_country
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
      s.segment,
      s.nice_9_name,
      coalesce(p.plan_group, s.plan_group_mi)  as plan_group,  -- snapshot prevalece; MI é fallback
      s.bu,

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
      s.order_source,
      s.social_network,
      s.source_details,
      s.source_type,

      s.total,
      s.total_in_usd,
      s.shipping_cost,
      s.product_quantity
      
  from orders_plus_store_plan_group s
  left join plans_snapshot p
    on p.store_id  = s.store_id
   and p.date_plan = s.date
