products_orders_unified_sql = f"""
-- PRODUCTS + ORDERS UNIFICADOS - REPO OFICIAL: Filtros alineados para consistencia
WITH

blocked_stores AS (
  {blocked_stores_query}
),

-- ✅ Orders deduplicados (mismo patrón que core)
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

-- Base de products con orders - FILTROS EXACTOS del repo oficial
products_orders_base AS (
  SELECT 
    o.store_id,
    mm.country_code AS country,
    
    -- Product info
    MAX(p.name_i18n) AS product_name,
    
    -- Fecha/hora local por completed_at  
    CASE 
      WHEN mm.country_code = 'AR' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Argentina/Buenos_Aires'))
      WHEN mm.country_code = 'MX' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Mexico_City'))
      WHEN mm.country_code = 'BR' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Sao_Paulo'))
      WHEN mm.country_code = 'CO' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Bogota'))
      WHEN mm.country_code = 'CL' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Santiago'))
    END AS fecha_hora,
    
    -- ✅ SIMPLIFICADO: Métricas agregadas (orders ya están paid por filtro base)
    COUNT(DISTINCT o.id) AS orders,
    SUM(o.total * p.quantity / total_products.total_quantity) AS gmv,
    SUM(p.quantity) AS products_quantity,
    MAX(o.completed_at) AS max_completed_at

  FROM orders_dedup o  -- ✅ Usar dedup
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  
  -- Products details con validaciones repo oficial
  INNER JOIN hive_metastore.orders.mwp_order_products p 
    ON p.order_id = o.id
    AND p.deleted_at IS NULL
    AND p.quantity > 0          -- ✅ Repo oficial: Excluir <= 0
    AND p.quantity < 999        -- ✅ Repo oficial: Excluir > 999
  
  -- Total products per order (para GMV proporcional)
  INNER JOIN (
    SELECT 
      order_id,
      SUM(quantity) AS total_quantity
    FROM hive_metastore.orders.mwp_order_products
    WHERE deleted_at IS NULL 
      AND quantity > 0 AND quantity < 999  -- ✅ Mismas validaciones
    GROUP BY order_id
  ) total_products ON total_products.order_id = o.id
  
  WHERE bs.store_id IS NULL
    -- 🎯 FILTROS EXACTOS DEL REPO OFICIAL (consistencia con core):
    AND o.payment_status = 'paid'      -- ✅ Solo órdenes pagas
    AND o.status <> 'cancelled'        -- ✅ Excluir canceladas  
    AND o.completed_at IS NOT NULL     -- ✅ Requerido
    AND o.storefront <> 'permalink'    -- ✅ Excluir permalink
    AND o.total_in_usd BETWEEN 0 AND 10000  -- ✅ Cap exacto repo oficial
    -- ✅ MANTENER: Configurabilidad
    AND mm.country_code IN ({', '.join([f"'{c}'" for c in COUNTRIES])})
    AND o.completed_at >= TIMESTAMP('{global_start}')
    AND o.completed_at <= TIMESTAMP('{global_end}')
    AND p.name_i18n IS NOT NULL        -- Productos con nombre
    AND TRIM(p.name_i18n) != ''        -- Nombre no vacío
      
  GROUP BY 
    o.store_id, 
    mm.country_code,
    p.product_id,  -- Agrupar por product_id
    CASE 
      WHEN mm.country_code = 'AR' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Argentina/Buenos_Aires'))
      WHEN mm.country_code = 'MX' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Mexico_City'))
      WHEN mm.country_code = 'BR' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Sao_Paulo'))
      WHEN mm.country_code = 'CO' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Bogota'))
      WHEN mm.country_code = 'CL' THEN 
        date_trunc('hour', from_utc_timestamp(o.completed_at, 'America/Santiago'))
    END
)

SELECT * FROM products_orders_base
WHERE product_name IS NOT NULL 
  AND TRIM(product_name) != ''
"""


