orders_sql_no_dedup = f"""
-- TEST: ORDERS SIN DEDUPLICACIÓN (igual al repo oficial)
WITH

blocked_stores AS (
  {blocked_stores_query}
),

-- ❌ ELIMINAR: orders_dedup CTE (sin deduplicación)

-- ✅ Order Sources optimizado (mantener)
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

-- 🎯 orders_base DIRECTO desde mwp_orders (igual al repo)
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
    
    -- Country desde store_info (corregido)
    si.country AS country_code,
    
    -- Order Source
    oss.source AS order_source,
    oss.source_details AS order_source_details,
    
    -- Promociones
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

  -- ✅ CAMBIO: Directo desde mwp_orders (sin dedup)
  FROM hive_metastore.orders.mwp_orders o
  LEFT JOIN merchant_complete mm ON mm.store_id = o.store_id
  INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  LEFT JOIN order_sources_one oss ON oss.order_id = o.id
  
  WHERE bs.store_id IS NULL
    AND o.year_month_code IN ({partition_filter})  -- ✅ Partition filter aquí
    AND si.state <> 4
    AND o.payment_status = 'paid'
    AND o.status <> 'cancelled'
    AND o.completed_at IS NOT NULL
    AND o.storefront <> 'permalink'
    AND o.total_in_usd BETWEEN 0 AND 10000
    AND si.country IN ({', '.join([f"'{c}'" for c in COUNTRIES])})
    AND o.completed_at >= TIMESTAMP('{global_start}')
    AND o.completed_at <= TIMESTAMP('{global_end}')
),

-- Payment dates y products (igual)
payment_dates AS (
  SELECT 
    order_id, MAX(happened_at) AS paid_at
  FROM hive_metastore.orders.mwp_orders_logging
  WHERE year_month_code IN ({partition_filter})
    AND data_2 = 'paid'
    AND order_id IN (SELECT order_pk FROM orders_base)
  GROUP BY order_id
),

products_qty AS (
  SELECT
    order_id, SUM(quantity) AS products_quantity
  FROM hive_metastore.orders.mwp_order_products
  WHERE deleted_at IS NULL
    AND quantity > 0 AND quantity < 999
    AND order_id IN (SELECT order_pk FROM orders_base) 
  GROUP BY order_id
)

SELECT 
  ob.*,
  pd.paid_at,
  COALESCE(pq.products_quantity, 0) AS products_quantity
FROM orders_base ob
LEFT JOIN payment_dates pd ON pd.order_id = ob.order_pk
LEFT JOIN products_qty pq ON pq.order_id = ob.order_pk
"""

print("🧪 PROBANDO: Orders SIN deduplicación (igual al repo oficial)...")
orders_df_test, orders_count_test = execute_sql_with_cache(orders_sql_no_dedup, "orders_no_dedup_test")

print(f"📊 RESULTADOS:")
print(f"   Con deduplicación:    177,037 orders")
print(f"   Sin deduplicación:    {orders_count_test:,} orders")
print(f"   Repo oficial:         181,468 orders")
print(f"   Diferencia:           {orders_count_test - 177037:,} orders recuperadas")


