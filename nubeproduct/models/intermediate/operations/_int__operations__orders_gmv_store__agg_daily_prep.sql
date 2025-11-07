
-- i__company_metrics__orders_gmv_store__agg_daily
-- Camada: intermediate
-- Objetivo: consolidar dimensões, tratamentos e métricas agregadas
--           por dia e por store (e demais dimensões), incluindo:
--           - plano vigente via snapshot diário (completed_at = date_plan)
--           - colunas de auditoria para o DP (sys_audit_day_max, checksum_day)

-- Agregado diário por store (e demais dimensões)
select
    -- Dimensões da Loja
    o.store_id,
    o.country,
    o.domain,
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
    count(distinct o.order_id)                                            as orders,
    sum(case when o.shipping_cost = 0 then 1 else 0 end) as orders_free_shipping,
    sum(o.product_quantity)                             as products

    from {{ ref('_int__orders__orders_enriched') }} o
    group by
    o.store_id, o.country, o.domain, o.vertical, o.province, o.city, o.region,
    o.business_size, o.max_seller_segment, o.current_seller_segment, o.historical_seller_segment,
    o.current_plan, o.historical_plan, o.current_bu, o.historical_bu,
    o.date, o.year_month_day_code, o.mes, o.platform_type, o.storefront, o.device,
    o.payment_provider, o.payment_method, o.shipping_method, o.shipping_province,
    o.gateway_installments, o.order_source, o.social_network, o.source_details, o.source_type