
-- Agregado diário (e demais dimensões) --> deve ser um novo intermediate Assim com ou sem store usará orders_enriched
select
    -- Dimensões da loja
    o.country,
    o.vertical,
    o.province,
    o.city,
    o.region,
    o.business_size,
    o.max_seller_segment,
    o.current_seller_segment,
    o.historical_seller_segment,
    o.current_plan,
    o.historical_plan,
    o.current_bu,
    o.historical_bu,

    -- Dimensões do Pedido (por dia)
    o.date,
    o.year_month_day_code, --completed_at info
    o.datemonth,
    o.platform_type,
    o.storefront,
    o.device,
    o.payment_provider,
    o.payment_method,
    o.shipping_method,
    o.shipping_province,
    o.gateway_installments,
    o.source_name,
    o.source_group,
    o.google_subchannel,
    o.traffic_type,
    o.is_end_user,
    o.visitor_country,

    -- Métricas
    sum(o.total_in_local_currency)                                        as gmv,
    sum(o.total_in_usd)                                 as gmv_usd,
    count(distinct o.order_id)                                as orders,
    sum(case when o.shipping_cost = 0 then 1 else 0 end) as orders_free_shipping,
    sum(o.product_quantity)                             as products,
    count(distinct o.store_id)                           as stores,

    max(o.sys_audit_updated_on)                         as sys_audit_updated_on

    from {{ ref('_int__orders__orders_enriched') }} o
    group by
    o.country, o.vertical, o.province, o.city, o.region,
    o.business_size, o.max_seller_segment, o.current_seller_segment, o.historical_seller_segment,
    o.current_plan, o.historical_plan, o.current_bu, o.historical_bu,
    o.date, o.year_month_day_code, o.datemonth, o.platform_type, o.storefront, o.device,
    o.payment_provider, o.payment_method, o.shipping_method, o.shipping_province,
    o.gateway_installments, o.source_name, o.source_group, o.google_subchannel, o.traffic_type, o.is_end_user, o.visitor_country