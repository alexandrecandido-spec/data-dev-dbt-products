# 🎯 ÚNICO CAMBIO NECESARIO: Agregar store state validation

# En tu orders_sql actual, cambiar:

# ❌ ANTES:
"""
  FROM orders_dedup o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
"""

# ✅ DESPUÉS:
"""
  FROM orders_dedup o
  INNER JOIN merchant_complete mm ON mm.store_id = o.store_id
  -- ✅ AGREGAR: Store state validation (exacto al repo oficial)
  INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id
  LEFT JOIN blocked_stores bs ON bs.store_id = o.store_id
  
  WHERE bs.store_id IS NULL
    AND si.state <> 4              -- ✅ NUEVO: Excluir stores inactivas (repo oficial)
    AND o.payment_status = 'paid'  -- ✅ Ya tienes esto
    -- ... resto de filtros igual
"""

# 📋 RESULTADO:
# ✅ Blocked stores: YA correcto
# ✅ Timezone: YA correcto (mejor que repo oficial)  
# ✅ Store state: NUEVO (necesario para coincidir)
# ✅ Mantiene merchant_complete: Para event tagging
# ✅ Todos los filtros del repo oficial: Números van a coincidir


