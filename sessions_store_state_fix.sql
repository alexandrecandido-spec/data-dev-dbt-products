-- 🎯 SESSIONS: Cambios en 3 CTEs (orders_base, sessions_base, carritos_base)

-- ✅ 1. orders_base CTE:
orders_base AS (
  FROM orders_dedup o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  -- ✅ AGREGAR: Store state validation
  INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  
  WHERE bs.store_id IS NULL
    AND si.state <> 4              -- ✅ NUEVO: Excluir stores inactivas
    AND o.payment_status = 'paid'
    -- ... resto filtros igual ...
),

-- ✅ 2. sessions_base CTE:
sessions_base AS (
  FROM hive_metastore.storefronts_curated.sessions s
  INNER JOIN merchant_complete mm ON s.store_id = mm.store_id
  -- ✅ AGREGAR: Store state validation
  INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = s.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = s.store_id
  
  WHERE bs.store_id IS NULL
    AND si.state <> 4              -- ✅ NUEVO: Excluir stores inactivas
    AND s.year IN ({years_filter})
    -- ... resto filtros igual ...
),

-- ✅ 3. carritos_base CTE:
carritos_base AS (
  FROM orders_dedup o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  -- ✅ AGREGAR: Store state validation
  INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  
  WHERE bs.store_id IS NULL
    AND si.state <> 4              -- ✅ NUEVO: Excluir stores inactivas
    AND o.status <> 'cancelled'
    -- ... resto filtros igual ...
)


