orders_sql = f"""
-- ORDERS SCOPED + PROMOCIONES - REPO OFICIAL: Filtros exactos del repo + Arquitectura original
WITH

blocked_stores AS (
  {blocked_stores_query}
),

-- ✅ Deduplicación CDC (útil)
orders_dedup AS (
  SELECT *
  FROM (
    SELECT o.*,
           ROW_NUMBER() OVER (PARTITION BY o.id ORDER BY o.updated_at DESC NULLS LAST) AS rnk
    FROM hive_metastore.orders.mwp_orders o
    WHERE o.year_month_code IN ({partition_filter})
  ) t
  WHERE rnk = 1
),

-- ✅ Order Sources optimizado
order_sources AS (
  SELECT order_id, source, source_details,
         ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY source_details) AS rnk
  FROM hive_metastore.orders.mwp_orders_source
  WHERE year_month_code IN ({partition_filter})
),
order_sources_one AS (
  SELECT order_id, source, source_details
  FROM order_sources
  WHERE rnk = 1
),

-- 🎯 orders_base con FILTROS EXACTOS del repo oficial + merchant_complete
orders_base AS (
  SELECT 
    o.id AS order_pk, 
    o.order_id, 
    o.store_id,
    LOWER(o.contact_email) AS contact_email,
    o.currency, 
    o.total, 
    o.total_in_usd, 
    o.storefront, 
    o.status,
    o.device_type, 
    o.payment_status, 
    o.gateway, 
    o.shipping_method,
    o.shipping_cost, 
    o.shipping_option, 
    o.shipping_pickup_type,
    o.shipping_province, 
    o.gateway_integration_type,
    o.gateway_installments, 
    o.gateway_method, 
    o.app_id,
    o.completed_at, 
    o.created_at,
    
    -- ✅ MANTENER: merchant_complete (CRÍTICO para event tagging)
    mm.country_code AS country_code,
    
    -- Order Source (optimizado)
    oss.source AS order_source,
    oss.source_details AS order_source_details,
    
    -- Promociones directamente incluidas
    CASE WHEN o.coupon_id IS NOT NULL THEN 1 ELSE 0 END AS orders_coupon,
    CASE WHEN o.promotional_discount_id IS NOT NULL THEN 1 ELSE 0 END AS orders_promo_price,
    CASE WHEN o.shipping_cost = 0 OR o.shipping_cost IS NULL THEN 1 ELSE 0 END AS orders_free_shipping,
    CASE WHEN (
      CASE WHEN o.coupon_id IS NOT NULL THEN 1 ELSE 0 END +
      CASE WHEN o.promotional_discount_id IS NOT NULL THEN 1 ELSE 0 END +
      CASE WHEN o.shipping_cost = 0 OR o.shipping_cost IS NULL THEN 1 ELSE 0 END
    ) > 0 THEN 1 ELSE 0 END AS orders_with_any_promotion,
    0 AS descuento_pct,
    'N/A' AS promotion_type

  FROM orders_dedup o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id  -- ✅ MANTENER para event tagging
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  LEFT JOIN order_sources_one oss ON oss.order_id = o.id
  
  WHERE bs.store_id IS NULL
    -- 🎯 FILTROS EXACTOS DEL REPO OFICIAL (para coincidir con landing):
    AND o.payment_status = 'paid'      -- ✅ Solo órdenes pagas (repo oficial)
    AND o.status <> 'cancelled'        -- ✅ Excluir canceladas (repo oficial)
    AND o.completed_at IS NOT NULL     -- ✅ Requerido (repo oficial)
    AND o.storefront <> 'permalink'    -- ✅ Excluir permalink (repo oficial)
    AND o.total_in_usd BETWEEN 0 AND 10000  -- ✅ Cap exacto del repo oficial
    -- 🎯 MANTENER: Configurabilidad temporal/geográfica  
    AND mm.country_code IN ({', '.join([f"'{c}'" for c in COUNTRIES])})
    AND o.completed_at >= TIMESTAMP('{global_start}')
    AND o.completed_at <= TIMESTAMP('{global_end}')
),

-- ✅ MANTENER: Payment dates optimizado (igual)
payment_dates AS (
  SELECT 
    order_id, MAX(happened_at) AS paid_at
  FROM hive_metastore.orders.mwp_orders_logging
  WHERE year_month_code IN ({partition_filter})
    AND data_2 = 'paid'
    AND order_id IN (SELECT order_pk FROM orders_base)
  GROUP BY order_id
),

-- ✅ Products quantity con FILTROS EXACTOS del repo oficial
products_qty AS (
  SELECT
    order_id, SUM(quantity) AS products_quantity
  FROM hive_metastore.orders.mwp_order_products
  WHERE deleted_at IS NULL
    AND quantity > 0          -- ✅ Repo oficial: Excluir cantidades <= 0
    AND quantity < 999        -- ✅ Repo oficial: Excluir cantidades irreales
    AND order_id IN (SELECT order_pk FROM orders_base) 
  GROUP BY order_id
)

-- 4. JOIN final (igual)
SELECT 
  ob.*,
  pd.paid_at,
  COALESCE(pq.products_quantity, 0) AS products_quantity
FROM orders_base ob
LEFT JOIN payment_dates pd ON pd.order_id = ob.order_pk
LEFT JOIN products_qty pq ON pq.order_id = ob.order_pk
"""
