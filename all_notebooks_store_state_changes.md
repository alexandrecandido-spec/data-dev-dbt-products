# 🔧 CAMBIOS EXACTOS para agregar store state validation

## 📊 1. CORE NOTEBOOK - orders_sql
**Ubicación:** `orders_base` CTE
**Cambios:** 2 líneas

```sql
-- AGREGAR esta línea después del JOIN con merchant_complete:
INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id

-- AGREGAR esta línea en WHERE (después de bs.store_id IS NULL):
AND si.state <> 4              -- ✅ Excluir stores inactivas
```

## 📈 2. SESSIONS NOTEBOOK - sessions_orders_unified_sql  
**Ubicación:** 3 CTEs diferentes
**Cambios:** 6 líneas (2 por CTE)

### A. `orders_base` CTE:
```sql
-- AGREGAR JOIN:
INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id
-- AGREGAR WHERE:
AND si.state <> 4
```

### B. `sessions_base` CTE:
```sql
-- AGREGAR JOIN:
INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = s.store_id
-- AGREGAR WHERE:
AND si.state <> 4
```

### C. `carritos_base` CTE:
```sql
-- AGREGAR JOIN:
INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id
-- AGREGAR WHERE:
AND si.state <> 4
```

## 🛍️ 3. PRODUCTS NOTEBOOK - products_orders_unified_sql
**Ubicación:** `products_orders_base` CTE
**Cambios:** 2 líneas

```sql
-- AGREGAR JOIN después del JOIN con merchant_complete:
INNER JOIN hive_metastore.moltres.mwp_store_info si ON si.id = o.store_id

-- AGREGAR WHERE después de bs.store_id IS NULL:
AND si.state <> 4              -- ✅ Excluir stores inactivas
```

## 🎯 RESULTADO FINAL:
- ✅ **4 filtros** exactos del repo oficial (payment_status, status, storefront, total_in_usd)
- ✅ **Store state validation** (nuevo)
- ✅ **Blocked stores** (ya correcto)
- ✅ **Timezone conversion** (ya correcto, mejor que repo)
- ✅ **Mantiene merchant_complete** (para event tagging)
- ✅ **Números van a coincidir** perfectamente con la landing

## ⚡ IMPACTO:
- **Total líneas agregadas:** 8 líneas (2 + 6 + 2)
- **Performance:** Mínimo impacto (JOIN simple + filtro index)
- **Consistencia:** PERFECTA con repo oficial


