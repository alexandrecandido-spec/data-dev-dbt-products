
-- Agregado diário (e demais dimensões) --> deve ser um novo intermediate Assim com ou sem store usará orders_enriched
select
    -- Dimensões da loja
    o.country,
    o.vertical,
    o.province,
    o.city,
    o.region,
    o.business_size,
    o.segment,
    o.nice_9_name,
    o.plan_group,
    o.bu,

    -- Dimensões do Pedido (por dia)
    o.date,
    o.year_month_day_code,
    o.mes,
    o.platform_type,
    o.storefront,
    o.device,
    o.payment_provider,
    o.payment_method,
    o.shipping_method,
    o.shipping_province,
    o.gateway_installments,
    o.order_source,
    o.social_network,
    o.source_details,
    o.source_type,

    -- Métricas
    sum(o.total)                                        as gmv,
    sum(o.total_in_usd)                                 as gmv_usd,
    count(distinct o.order_id)                                as orders,
    sum(case when o.shipping_cost = 0 then 1 else 0 end) as orders_free_shipping,
    sum(o.product_quantity)                             as products,
    count(distinct o.store_id)                           as stores

    from {{ ref('_int__orders__orders_enriched') }} o
    group by
    o.country, o.vertical, o.province, o.city, o.region,
    o.business_size, o.segment, o.nice_9_name, o.plan_group, o.bu,
    o.date, o.year_month_day_code, o.mes, o.platform_type, o.storefront, o.device,
    o.payment_provider, o.payment_method, o.shipping_method, o.shipping_province,
    o.gateway_installments, o.order_source, o.social_network, o.source_details, o.source_type