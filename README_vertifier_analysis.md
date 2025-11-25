# Análisis por Vertifier - Migración Redshift → Databricks

Esta query replica el análisis de GMV por vertical de la query original de Redshift, pero adaptada para usar `vertifier` (clasificación automática por ML) en lugar de `type` (clasificación manual).

## 🔄 Cambios Realizados

### 1. Referencias de Tablas

| Redshift | Databricks |
|----------|------------|
| `tiendanube.mwp_store_info` | `hive_metastore.moltres.mwp_store_info` |
| `tiendanube.mwp_store_settings` | `hive_metastore.moltres.mwp_store_settings` ✅ |
| `tiendanube.mwp_orders` | `hive_metastore.orders.mwp_orders` |
| `moltres.mwp_tags` | `hive_metastore.moltres.mwp_tags` |
| ➕ **Nueva:** | `hive_metastore.antifraud_service.vertifier_store_inferences` |

### 2. Lógica de Clasificación

#### Original (solo `type` manual):
```sql
CASE
  WHEN s.type IN ('clothing_accesories','clothing','jewelry') THEN 'clothing'
  WHEN s.type IN ('gifts','bookstore_graphic','books','education','art') THEN 'books'
  WHEN s.type IN ('electronics_it','health_beauty','food_drinks','home_garden') THEN s.type
  ELSE 'other'
END
```

#### Nueva (combinando `type` + `vertifier` como en dbt):
```sql
-- 1. Primero crear la clasificación combinada (igual que en dbt)
CASE 
    WHEN s.type IS NULL THEN v.vertifier_classification 
    ELSE s.type 
END AS final_classification

-- 2. Luego aplicar la lógica de agrupación (expandida para incluir valores de vertifier)
CASE
  WHEN final_classification IN ('clothing_accesories','clothing','jewelry','fashion','apparel','accessories') THEN 'clothing'
  WHEN final_classification IN ('gifts','bookstore_graphic','books','education','art','stationery') THEN 'books'
  WHEN final_classification IN ('electronics_it','electronics','technology','computers','phones') THEN 'electronics_it'
  WHEN final_classification IN ('health_beauty','beauty','cosmetics','health','wellness') THEN 'health_beauty'
  WHEN final_classification IN ('food_drinks','food','drinks','beverages','restaurant') THEN 'food_drinks'
  WHEN final_classification IN ('home_garden','home','garden','furniture','decor') THEN 'home_garden'
  ELSE 'other'
END
```

### 3. Conversión de Timezone

#### Redshift:
```sql
convert_timezone('UTC','America/Buenos_Aires', o.completed_at)
```

#### Databricks:
```sql
from_utc_timestamp(o.completed_at, 'America/Argentina/Buenos_Aires')
```

### 4. Nueva Lógica Combinada (Igual que dbt)

Se agregan CTEs para replicar exactamente la lógica de dbt:

```sql
-- 1. Vertifier más reciente por tienda (fallback)
latest_vertifier AS (...)

-- 2. Lógica de prioridad (IGUAL que en dbt)
store_classification AS (
    SELECT 
        s.store_id,
        CASE 
            WHEN s.type IS NULL THEN v.vertifier_classification  -- ← Fallback a vertifier
            ELSE s.type                                          -- ← Prioridad a type manual
        END AS final_classification
    FROM hive_metastore.moltres.mwp_store_settings s
    LEFT JOIN latest_vertifier v ON v.store_id = s.store_id
)
```

## 📊 Resultados Esperados

La query devuelve los mismos campos que la original:

| Campo | Descripción | Tipo |
|-------|-------------|------|
| `vertical` | Vertical clasificado (clothing, books, electronics_it, etc.) | STRING |
| `gmv` | Gross Merchandise Value total | DECIMAL |
| `orders` | Número total de órdenes | BIGINT |
| `avg_ticket` | Ticket promedio (GMV/órdenes) | DECIMAL(18,2) |

## ⚠️ Diferencias Importantes

### 1. Fuente de Clasificación (Lógica de Prioridad)
- **Original**: Solo `mwp_store_settings.type` (clasificación manual)
- **Nueva**: **Combinación con prioridad** (igual que en dbt):
  1. **Primero** `mwp_store_settings.type` (manual) si existe
  2. **Fallback** `vertifier_store_inferences.primary.name` (automático) si type es NULL

### 2. Cobertura de Datos (Mejorada)
- **Original**: Solo tiendas con clasificación manual
- **Nueva**: 
  - Tiendas con clasificación manual (**mismos datos que antes**)
  - ➕ **Más tiendas** con clasificación automática (vertifier) cuando no hay manual

### 3. Valores Expandidos
Los valores en `final_classification` ahora incluyen tanto valores de `type` como de `vertifier`, por eso las condiciones CASE están expandidas para manejar ambos tipos de valores.

## 🔍 Para Verificar Valores de Vertifier

Antes de ejecutar la query principal, puedes explorar qué valores existen:

```sql
-- Ver todos los vertifiers únicos y su frecuencia
SELECT 
    CAST(primary.name AS STRING) AS vertifier,
    COUNT(DISTINCT storeid) AS stores_count,
    COUNT(*) AS total_inferences
FROM hive_metastore.antifraud_service.vertifier_store_inferences
WHERE primary.name IS NOT NULL
GROUP BY CAST(primary.name AS STRING)
ORDER BY stores_count DESC;
```

```sql
-- Ver ejemplos por vertifier
SELECT 
    CAST(primary.name AS STRING) AS vertifier,
    CAST(storeid AS BIGINT) AS store_id,
    createdat
FROM hive_metastore.antifraud_service.vertifier_store_inferences
WHERE primary.name IS NOT NULL
ORDER BY primary.name, createdat DESC;
```

## 🚀 Uso Recomendado

### 1. Verificación Inicial
```sql
-- Contar tiendas con vertifier vs sin vertifier
SELECT 
    CASE WHEN v.vertifier_classification IS NOT NULL THEN 'Con Vertifier' ELSE 'Sin Vertifier' END as classification_status,
    COUNT(DISTINCT i.id) as stores_count
FROM hive_metastore.moltres.mwp_store_info i
LEFT JOIN latest_vertifier v ON v.store_id = i.id
WHERE i.country = 'AR' AND i.state <> 4
GROUP BY 1;
```

### 2. Validar Lógica de Prioridad
Para verificar que la lógica de prioridad funciona correctamente:

```sql
-- Ver cómo se distribuye la clasificación final
WITH latest_vertifier AS (...),  -- Tu CTE completo
store_classification AS (...)     -- Tu CTE completo

SELECT 
    s.type as manual_type,
    v.vertifier_classification as automatic_vertifier,
    sc.final_classification as final_result,
    COUNT(DISTINCT i.id) as stores_count,
    CASE 
        WHEN s.type IS NOT NULL THEN 'Used Manual (type)'
        WHEN v.vertifier_classification IS NOT NULL THEN 'Used Automatic (vertifier)'
        ELSE 'No Classification'
    END as classification_source
FROM hive_metastore.moltres.mwp_store_info i
LEFT JOIN hive_metastore.moltres.mwp_store_settings s ON s.store_id = i.id  
LEFT JOIN latest_vertifier v ON v.store_id = i.id
LEFT JOIN store_classification sc ON sc.store_id = i.id
WHERE i.country = 'AR' AND i.state <> 4
GROUP BY 1, 2, 3, 5
ORDER BY stores_count DESC;
```

### 3. Comparación Completa
Para ver el impacto del cambio:

```sql
-- Comparar cobertura: Solo type vs Type + Vertifier
SELECT 
    'Solo Type (Original)' as method,
    COUNT(DISTINCT CASE WHEN s.type IS NOT NULL THEN i.id END) as classified_stores,
    COUNT(DISTINCT i.id) as total_stores
FROM hive_metastore.moltres.mwp_store_info i
LEFT JOIN hive_metastore.moltres.mwp_store_settings s ON s.store_id = i.id
WHERE i.country = 'AR' AND i.state <> 4

UNION ALL

SELECT 
    'Type + Vertifier (Nuevo)' as method,
    COUNT(DISTINCT CASE WHEN sc.final_classification IS NOT NULL THEN i.id END) as classified_stores,
    COUNT(DISTINCT i.id) as total_stores
FROM hive_metastore.moltres.mwp_store_info i
LEFT JOIN store_classification sc ON sc.store_id = i.id
WHERE i.country = 'AR' AND i.state <> 4;
```

## ⚡ Optimizaciones

### Performance Tips:
1. **Filtro temporal**: La query ya incluye filtros de fecha eficientes
2. **Índices**: Asegúrate de que las tablas tengan índices en `store_id` y `completed_at`
3. **Particionamiento**: Las tablas grandes deberían estar particionadas por fecha

### Ajustes Opcionales:
```sql
-- Para ejecutar con rango de fechas variable:
-- Reemplaza las fechas hardcodeadas por parámetros:
AND from_utc_timestamp(o.completed_at, 'America/Argentina/Buenos_Aires') >= '${start_date}'
AND from_utc_timestamp(o.completed_at, 'America/Argentina/Buenos_Aires') < '${end_date}'
```

¡La query está lista para ejecutar en Databricks! Solo ajusta las clasificaciones de vertifier según los valores reales que encuentres en tu entorno.
