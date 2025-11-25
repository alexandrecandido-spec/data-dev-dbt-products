sessions_orders_unified_sql = f"""
-- SESSIONS + ORDERS + CARRITOS UNIFICADOS - REPO OFICIAL: Filtros alineados manteniendo funcionalidad completa
WITH

blocked_stores AS (
  {blocked_stores_query}
),

-- ✅ Orders deduplicados (añadir CDC)
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

-- Base de orders con FILTROS EXACTOS del repo oficial (pero manteniendo estructura)
orders_base AS (
  SELECT 
    o.store_id,
    mm.country_code AS country,
    
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
    
    -- ✅ SIMPLIFICADO: Métricas de orders (orders ya están paid por filtro base)
    COUNT(DISTINCT o.id) AS orders,
    SUM(o.total) AS gmv,
    SUM(COALESCE(pq.products_quantity, 0)) AS products_quantity,
    MAX(o.completed_at) AS max_completed_at

  FROM orders_dedup o  -- ✅ Usar dedup
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  
  -- Products quantity con validaciones repo oficial
  LEFT JOIN (
    SELECT
      order_id, SUM(quantity) AS products_quantity
    FROM hive_metastore.orders.mwp_order_products
    WHERE deleted_at IS NULL
      AND quantity > 0 AND quantity < 999  -- ✅ Repo oficial
    GROUP BY order_id
  ) pq ON pq.order_id = o.id
  
  WHERE bs.store_id IS NULL
    -- 🎯 FILTROS EXACTOS DEL REPO OFICIAL:
    AND o.payment_status = 'paid'      -- ✅ Solo órdenes pagas (repo oficial)
    AND o.status <> 'cancelled'        -- ✅ Excluir canceladas (repo oficial) 
    AND o.completed_at IS NOT NULL     -- ✅ Requerido (repo oficial)
    AND o.storefront <> 'permalink'    -- ✅ Excluir permalink (repo oficial)
    AND o.total_in_usd BETWEEN 0 AND 10000  -- ✅ Cap exacto repo oficial
    AND mm.country_code IN ({', '.join([f"'{c}'" for c in COUNTRIES])})
    AND o.completed_at >= TIMESTAMP('{global_start}')
    AND o.completed_at <= TIMESTAMP('{global_end}')
      
  GROUP BY 
    o.store_id, 
    mm.country_code,
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
),

-- ✅ MANTENER: Sessions base (sin cambios - no afectado por repo oficial)
sessions_base AS (
  SELECT 
    s.store_id,
    mm.country_code AS country,
    
    -- Fecha/hora local por timestamp 
    CASE 
      WHEN mm.country_code = 'AR' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Argentina/Buenos_Aires'))
      WHEN mm.country_code = 'MX' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Mexico_City'))
      WHEN mm.country_code = 'BR' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Sao_Paulo'))
      WHEN mm.country_code = 'CO' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Bogota'))
      WHEN mm.country_code = 'CL' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Santiago'))
    END AS fecha_hora,
    
    -- Métricas de sessions
    COUNT(DISTINCT s.session_id) AS sessions,
    COUNT(DISTINCT s.consumer_id) AS visitors,
    MAX(s.timestamp) AS max_session_timestamp

  FROM hive_metastore.storefronts_curated.sessions s
  INNER JOIN merchant_complete mm ON s.store_id = mm.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = s.store_id
  WHERE bs.store_id IS NULL
    AND s.year IN ({years_filter})          -- ✅ PARTITION PRUNING SESSIONS!
    AND s.month IN ({months_filter})        -- ✅ PARTITION PRUNING SESSIONS!
    AND s.country = mm.country_code
    AND s.timestamp >= TIMESTAMP('{global_start}')
    AND s.timestamp <= TIMESTAMP('{global_end}')
    
  GROUP BY 
    s.store_id, 
    mm.country_code,
    CASE 
      WHEN mm.country_code = 'AR' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Argentina/Buenos_Aires'))
      WHEN mm.country_code = 'MX' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Mexico_City'))
      WHEN mm.country_code = 'BR' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Sao_Paulo'))
      WHEN mm.country_code = 'CO' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Bogota'))
      WHEN mm.country_code = 'CL' THEN 
        date_trunc('hour', from_utc_timestamp(s.timestamp, 'America/Santiago'))
    END
),

-- Carritos base - APLICAR filtros repo oficial para consistencia
carritos_base AS (
  SELECT 
    o.store_id,
    mm.country_code AS country,
    
    -- Fecha/hora local por started_checkout
    CASE 
      WHEN mm.country_code = 'AR' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Argentina/Buenos_Aires'))
      WHEN mm.country_code = 'MX' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Mexico_City'))
      WHEN mm.country_code = 'BR' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Sao_Paulo'))
      WHEN mm.country_code = 'CO' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Bogota'))
      WHEN mm.country_code = 'CL' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Santiago'))
    END AS fecha_hora,
    
    -- Métricas de carritos
    COUNT(DISTINCT o.id) AS carritos,
    MAX(o.started_checkout) AS max_started_checkout

  FROM orders_dedup o  -- ✅ Usar dedup también para carritos
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  WHERE bs.store_id IS NULL
    -- 🎯 APLICAR algunos filtros repo oficial para consistencia (pero no payment_status):
    AND o.status <> 'cancelled'        -- ✅ Excluir canceladas
    AND o.storefront <> 'permalink'    -- ✅ Excluir permalink  
    AND o.total_in_usd BETWEEN 0 AND 10000  -- ✅ Cap repo oficial
    AND mm.country_code IN ({', '.join([f"'{c}'" for c in COUNTRIES])})
    AND o.started_checkout IS NOT NULL
    AND o.started_checkout >= TIMESTAMP('{global_start}')
    AND o.started_checkout <= TIMESTAMP('{global_end}')
    
  GROUP BY 
    o.store_id, 
    mm.country_code,
    CASE 
      WHEN mm.country_code = 'AR' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Argentina/Buenos_Aires'))
      WHEN mm.country_code = 'MX' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Mexico_City'))
      WHEN mm.country_code = 'BR' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Sao_Paulo'))
      WHEN mm.country_code = 'CO' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Bogota'))
      WHEN mm.country_code = 'CL' THEN 
        date_trunc('hour', from_utc_timestamp(o.started_checkout, 'America/Santiago'))
    END
),

-- ✅ MANTENER: UNIÓN COMPLETA de las 3 fuentes (sin cambios)
unified_sessions_orders AS (
  SELECT 
    COALESCE(ob.store_id, sb.store_id, cb.store_id) AS store_id,
    COALESCE(ob.country, sb.country, cb.country) AS country,
    COALESCE(ob.fecha_hora, sb.fecha_hora, cb.fecha_hora) AS fecha_hora,
    
    -- Métricas de orders (paid)
    COALESCE(ob.orders, 0) AS orders,
    COALESCE(ob.gmv, 0) AS gmv,
    COALESCE(ob.products_quantity, 0) AS products_quantity,
    ob.max_completed_at,
    
    -- Métricas de sessions
    COALESCE(sb.sessions, 0) AS sessions,
    COALESCE(sb.visitors, 0) AS visitors,
    sb.max_session_timestamp,
    
    -- Métricas de carritos
    COALESCE(cb.carritos, 0) AS carritos,
    cb.max_started_checkout

  FROM orders_base ob
  FULL OUTER JOIN sessions_base sb ON ob.store_id = sb.store_id AND ob.fecha_hora = sb.fecha_hora
  FULL OUTER JOIN carritos_base cb ON COALESCE(ob.store_id, sb.store_id) = cb.store_id 
    AND COALESCE(ob.fecha_hora, sb.fecha_hora) = cb.fecha_hora
  
  WHERE COALESCE(ob.store_id, sb.store_id, cb.store_id) IS NOT NULL
    AND COALESCE(ob.fecha_hora, sb.fecha_hora, cb.fecha_hora) IS NOT NULL
)

SELECT * FROM unified_sessions_orders
"""


