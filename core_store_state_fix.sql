-- 🎯 CORE: Agregar en orders_base CTE

-- ❌ ANTES (tu versión actual):
orders_base AS (
  SELECT 
    o.id AS order_pk,
    -- ... columnas ...
    mm.country_code AS country_code,
    -- ... resto columnas ...

  FROM orders_dedup o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  LEFT JOIN order_sources_one oss ON oss.order_id = o.id
  
  WHERE bs.store_id IS NULL
    AND o.payment_status = 'paid'
    -- ... resto filtros ...
)

-- ✅ DESPUÉS (con store state):
orders_base AS (
  SELECT 
    o.id AS order_pk,
    -- ... columnas ...
    mm.country_code AS country_code,
    -- ... resto columnas ...

  FROM orders_dedup o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  -- ✅ AGREGAR: Store state validation
  INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  LEFT JOIN order_sources_one oss ON oss.order_id = o.id
  
  WHERE bs.store_id IS NULL
    AND si.state <> 4              -- ✅ NUEVO: Excluir stores inactivas
    AND o.payment_status = 'paid'
    -- ... resto filtros igual ...
)


