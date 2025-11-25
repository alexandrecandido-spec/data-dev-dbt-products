# ✅ SESSIONS también debe adaptarse para consistencia

orders_aggregated_sql = f"""
-- ORDERS AGGREGATED - REPO OFICIAL: Filtros alineados  
WITH

blocked_stores AS (
  {blocked_stores_query}
),

-- ✅ Orders deduplicados (mismo patrón)
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

orders_aggregated AS (
  SELECT
    o.store_id,
    mm.country_code AS country,
    
    -- Fecha/hora local
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
    
    -- ✅ SIMPLIFICADO: Métricas agregadas (orders ya paid por filtro)
    COUNT(DISTINCT o.id) AS orders,
    SUM(o.total) AS gmv,
    SUM(pq.products_quantity) AS products_quantity,
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
    -- 🎯 FILTROS EXACTOS DEL REPO OFICIAL (consistencia):
    AND o.payment_status = 'paid'      -- ✅ Solo órdenes pagas
    AND o.status <> 'cancelled'        -- ✅ Excluir canceladas
    AND o.completed_at IS NOT NULL     -- ✅ Requerido  
    AND o.storefront <> 'permalink'    -- ✅ Excluir permalink
    AND o.total_in_usd BETWEEN 0 AND 10000  -- ✅ Cap repo oficial
    AND mm.country_code IN ({', '.join([f"'{c}'" for c in COUNTRIES])})
    AND o.completed_at >= TIMESTAMP('{global_start}')
    AND o.completed_at <= TIMESTAMP('{global_end}')
    
  GROUP BY 
    o.store_id,
    mm.country_code,
    -- Repetir expresión completa (Databricks no soporta alias en GROUP BY)
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

SELECT * FROM orders_aggregated
"""

print("✅ SESSIONS adaptada con filtros exactos del repo oficial")


