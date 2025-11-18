# Documentación Técnica y Funcional
## Modelo: `g__product_marketing__storefront_sessions_store__agg`

---

## 📋 Resumen Ejecutivo

**Modelo:** `g__product_marketing__storefront_sessions_store__agg`  
**Tipo:** GOLD AGG (Data Product)  
**Dominio:** Marketing  
**Granularidad:** Una fila por tienda (`store_id`)  
**Materialización:** INCREMENTAL con estrategia MERGE  
**Ejecución:** Diaria a las 7:00 AM (tag: `daily_7am`)

### Propósito
Este modelo calcula métricas agregadas de sesiones reales de usuarios finales en storefronts por tienda durante el proceso de onboarding. Cuenta sesiones únicas en diferentes ventanas de tiempo (7d, 15d, 30d, 60d, 90d) desde la creación de la tienda, excluyendo merchants, bots y tráfico no-humano.

---

## 🎯 Funcionalidad

### Objetivo de Negocio
Medir el engagement de usuarios finales con las tiendas durante el onboarding. Este modelo proporciona métricas clave para entender qué tan activas son las tiendas desde la perspectiva de sus visitantes reales.

### Casos de Uso
1. **Tracking de Engagement:** Identificar tiendas con alto/bajo tráfico de usuarios finales.
2. **Análisis de Onboarding:** Medir la efectividad del onboarding en términos de atracción de tráfico.
3. **Segmentación:** Segmentar tiendas por nivel de engagement (alto, medio, bajo tráfico).
4. **Alertas:** Identificar tiendas que no reciben tráfico después de X días desde su creación.
5. **Análisis de Conversión:** Correlacionar tráfico con conversión y ventas.

### Definición de "Sesión"
Una **sesión** se considera válida cuando:
- Es de un **usuario final** (`is_end_user = TRUE`)
- Excluye merchants (dueños de tiendas)
- Excluye bots y tráfico no-humano
- Está asociada a una tienda creada después de `2024-01-01`

### Fuente Única de Verdad (SSOT)
- **Modelo:** `s__traffic__session__event` (Bárbara Aires)
- **Dominio:** Product
- **Descripción:** Modelo SILVER que contiene sesiones de storefronts con clasificación de usuarios y tráfico

---

## 🏗️ Arquitectura Técnica

### Dependencias

#### Modelos (Refs)
- **`s__traffic__session__event`**
  - **Tipo:** SILVER (Data Product)
  - **Owner:** Bárbara Aires
  - **Descripción:** Sesiones de storefronts con clasificación de usuarios y tráfico
  - **Columnas utilizadas:**
    - `store_id`
    - `session_id`
    - `session_timestamp`
    - `base_date`
    - `is_end_user` (filtro: solo `TRUE`)
- **`s__attributes__store_core__ref`**
  - **Tipo:** Dimensión canónica de atributos core de tiendas
  - **Uso:** Filtrado de tiendas creadas después de `2024-01-01` y obtención de `created_at`
  - **Columnas utilizadas:**
    - `store_id`
    - `created_at`

### Estructura de Datos

#### Columnas de Salida

| Columna | Tipo | Descripción | Valores Posibles |
|---------|------|-------------|------------------|
| `store_id` | BIGINT | ID único de la tienda | Cualquier `store_id` válido |
| `first_store_session` | DATE | Fecha de la primera sesión registrada en la tienda | `NULL` si no hay sesiones<br>Fecha si hay sesiones |
| `store_sessions_7d` | BIGINT | Cantidad de sesiones únicas en los primeros 7 días desde creación | `0` o mayor |
| `store_sessions_15d` | BIGINT | Cantidad de sesiones únicas en los primeros 15 días desde creación | `0` o mayor |
| `store_sessions_30d` | BIGINT | Cantidad de sesiones únicas en los primeros 30 días desde creación | `0` o mayor |
| `store_sessions_60d` | BIGINT | Cantidad de sesiones únicas en los primeros 60 días desde creación | `0` o mayor |
| `store_sessions_90d` | BIGINT | Cantidad de sesiones únicas en los primeros 90 días desde creación | `0` o mayor |
| `total_store_sessions` | BIGINT | Total de sesiones únicas (sin límite de tiempo) | `0` o mayor |
| `last_store_session` | DATE | Fecha de la última sesión registrada | `NULL` si no hay sesiones<br>Fecha si hay sesiones |
| `last_processed_date` | DATE | Última fecha de datos procesados (para próximo incremental) | Fecha |
| `sys_audit_created_on` | TIMESTAMP | Timestamp de creación del registro | Timestamp |
| `sys_audit_created_by` | STRING | Identificador del proceso que creó el registro | `'data-dev-dbt-products'` |
| `sys_audit_updated_on` | TIMESTAMP | Timestamp de última actualización | Timestamp |
| `sys_audit_updated_by` | STRING | Identificador del proceso que actualizó el registro | `'data-dev-dbt-products'` |

---

## ⚙️ Lógica de Procesamiento

### Flujo de Datos

```
1. existing_data CTE
   └─> Obtiene datos existentes de la tabla (store_id, audit fields)
       └─> Usa macro get_existing_data()

2. stores_to_update CTE (solo en modo incremental)
   └─> Identifica tiendas con sesiones nuevas desde última ejecución
       └─> Filtra por base_date > MAX(last_processed_date)
       └─> Solo is_end_user = TRUE

3. session_metrics CTE
   └─> JOIN s__traffic__session__event con s__attributes__store_core__ref
   └─> Filtra:
       - is_end_user = TRUE (solo usuarios finales)
       - s.created_at >= '2024-01-01' (solo tiendas recientes)
       - En incremental: solo tiendas en stores_to_update
   └─> Calcula métricas:
       - first_store_session: MIN(DATE(session_timestamp))
       - store_sessions_Xd: COUNT(DISTINCT session_id) por ventana de tiempo
       - total_store_sessions: COUNT(DISTINCT session_id) total
       - last_store_session: MAX(DATE(session_timestamp))
       - last_processed_date: MAX(base_date)

4. SELECT Final
   └─> LEFT JOIN session_metrics con existing_data
   └─> Preserva audit fields de primera carga
   └─> Actualiza sys_audit_updated_on/by
```

### Lógica Incremental

El modelo usa materialización **INCREMENTAL** con estrategia **MERGE** y `unique_key='store_id'`.

#### Modo Full Refresh
- Procesa **todas** las tiendas creadas después de `2024-01-01` con sesiones de usuarios finales.
- Recalcula todas las métricas desde cero.

#### Modo Incremental
Procesa **únicamente** tiendas con sesiones nuevas:
1. **Identificación de tiendas a actualizar:**
   - `stores_to_update` CTE identifica tiendas con `base_date > MAX(last_processed_date)`
   - Solo considera sesiones de usuarios finales (`is_end_user = TRUE`)

2. **Recálculo completo:**
   - Para cada tienda identificada, **recalcula todas las métricas** desde el inicio
   - Esto asegura que las ventanas de tiempo (7d, 15d, 30d, 60d, 90d) se actualicen correctamente cuando una tienda pasa de un período a otro

**Comportamiento:**
- ✅ **Actualiza** tiendas con nuevas sesiones, recalculando todas las métricas
- ✅ **Preserva** campos de auditoría (`sys_audit_created_on`, `sys_audit_created_by`) de la primera carga
- ✅ **Optimización:** Reduce tiempo de ejecución de 10+ minutos a segundos

### Agregaciones y Funciones SQL

#### Agregaciones en session_metrics
- **`MIN(DATE(session_timestamp))`**: Primera sesión registrada
- **`COUNT(DISTINCT session_id)`**: Conteo de sesiones únicas
  - Usado con `CASE WHEN` para filtrar por ventanas de tiempo
  - `COUNT(DISTINCT(CASE WHEN DATEDIFF(...) <= X THEN session_id ELSE NULL END))`
- **`MAX(DATE(session_timestamp))`**: Última sesión registrada
- **`MAX(base_date)`**: Última fecha procesada para próximo incremental

#### Funciones de Fecha
- **`DATEDIFF(DAY, s.created_at, sess.session_timestamp)`**: Calcula días entre creación de tienda y sesión
- **`DATE(session_timestamp)`**: Convierte timestamp a fecha

---

## 🔍 Ejemplos de Consultas

### Ejemplo 1: Tiendas con más sesiones en los primeros 30 días
```sql
SELECT 
    store_id,
    store_sessions_30d,
    first_store_session,
    last_store_session
FROM {{ ref('g__product_marketing__storefront_sessions_store__agg') }}
WHERE store_sessions_30d > 0
ORDER BY store_sessions_30d DESC
LIMIT 10;
```

### Ejemplo 2: Tasa de crecimiento de sesiones por ventana de tiempo
```sql
SELECT 
    store_id,
    store_sessions_7d,
    store_sessions_15d,
    store_sessions_30d,
    store_sessions_60d,
    store_sessions_90d,
    -- Crecimiento entre ventanas
    CASE 
        WHEN store_sessions_7d > 0 
        THEN ROUND((store_sessions_15d - store_sessions_7d) * 100.0 / store_sessions_7d, 2)
        ELSE NULL
    END AS growth_7d_to_15d_pct
FROM {{ ref('g__product_marketing__storefront_sessions_store__agg') }}
WHERE store_sessions_7d > 0
ORDER BY growth_7d_to_15d_pct DESC;
```

### Ejemplo 3: Tiendas sin sesiones después de 15 días
```sql
SELECT 
    s.store_id,
    s.created_at AS store_created_at,
    DATEDIFF(CURRENT_DATE, DATE(s.created_at)) AS days_since_creation,
    ss.store_sessions_15d,
    ss.first_store_session
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN {{ ref('g__product_marketing__storefront_sessions_store__agg') }} ss
    ON s.store_id = ss.store_id
WHERE s.created_at > '2024-01-01'
    AND (ss.store_sessions_15d = 0 OR ss.store_sessions_15d IS NULL)
    AND DATEDIFF(CURRENT_DATE, DATE(s.created_at)) >= 15
ORDER BY days_since_creation DESC;
```

### Ejemplo 4: Correlación entre sesiones y configuración de productos
```sql
SELECT 
    ss.store_id,
    ss.store_sessions_30d,
    p.config_products,
    CASE 
        WHEN ss.store_sessions_30d >= 100 AND p.config_products = 1 THEN 'Alto tráfico + Productos'
        WHEN ss.store_sessions_30d >= 100 AND p.config_products = 0 THEN 'Alto tráfico - Sin productos'
        WHEN ss.store_sessions_30d < 100 AND p.config_products = 1 THEN 'Bajo tráfico + Productos'
        ELSE 'Bajo tráfico - Sin productos'
    END AS segment
FROM {{ ref('g__product_marketing__storefront_sessions_store__agg') }} ss
LEFT JOIN {{ ref('s__product_marketing__products__ref') }} p
    ON ss.store_id = p.store_id
WHERE ss.store_sessions_30d > 0
ORDER BY ss.store_sessions_30d DESC;
```

---

## ✅ Validaciones y Tests

### Tests de Calidad de Datos

| Test | Columna | Descripción |
|------|---------|-------------|
| `not_null` | `store_id` | Garantiza que todas las filas tengan un `store_id` |
| `unique` | `store_id` | Garantiza que no haya duplicados por `store_id` |

### Validaciones Manuales Recomendadas

1. **Consistencia de fechas:**
   - `first_store_session <= last_store_session` (si ambos no son NULL)
   - `first_store_session` y `last_store_session` deben ser >= `2024-01-01`

2. **Consistencia de contadores:**
   - `store_sessions_7d <= store_sessions_15d <= store_sessions_30d <= store_sessions_60d <= store_sessions_90d <= total_store_sessions`
   - Si `total_store_sessions > 0`, entonces `first_store_session` y `last_store_session` NO deben ser NULL

3. **Consistencia de last_processed_date:**
   - `last_processed_date` debe ser <= `CURRENT_DATE`
   - `last_processed_date` debe ser >= `2024-01-01`

4. **Auditoría:**
   - `sys_audit_created_on <= sys_audit_updated_on`
   - `sys_audit_created_by` y `sys_audit_updated_by` deben ser `'data-dev-dbt-products'`

---

## 🚀 Ejecución y Mantenimiento

### Comandos de Validación

```bash
# Full refresh (primera ejecución o reset completo)
dbt build --select g__product_marketing__storefront_sessions_store__agg --full-refresh

# Ejecución incremental (ejecución normal)
dbt build --select g__product_marketing__storefront_sessions_store__agg

# Validación de documentación
dbt run-operation required_docs

# Compilación (sin ejecutar)
dbt compile --select g__product_marketing__storefront_sessions_store__agg
```

### Frecuencia de Ejecución
- **Automática:** Diaria a las 7:00 AM (tag: `daily_7am`)
- **Manual:** Cuando sea necesario actualizar datos históricos o corregir errores

### Monitoreo Recomendado

1. **Volumen de datos:**
   - Verificar que el número de filas aumente gradualmente (solo tiendas nuevas o con sesiones nuevas).
   - Alertar si hay un crecimiento anómalo.

2. **Calidad:**
   - Monitorear que los tests pasen en cada ejecución.
   - Verificar que no haya `store_id` duplicados.
   - Validar consistencia de contadores (7d <= 15d <= 30d <= 60d <= 90d <= total).

3. **Performance:**
   - Monitorear tiempo de ejecución (debe ser < 5 minutos en modo incremental).
   - Alertar si la ejecución tarda más de lo esperado.

4. **Disponibilidad de datos fuente:**
   - Verificar disponibilidad de `s__traffic__session__event`:
     ```sql
     SELECT MAX(base_date) FROM data_products_dev.testing_product.s__traffic__session__event
     ```
   - Alertar si `MAX(base_date)` está desactualizado (> 2 días de retraso).

---

## ⚠️ Limitaciones y Consideraciones

### Limitaciones Conocidas

1. **Filtro de fecha:** Solo procesa tiendas creadas después de `2024-01-01`.
   - **Impacto:** Tiendas anteriores a esta fecha no aparecerán en el modelo.
   - **Razón:** Optimización de performance y enfoque en tiendas recientes.

2. **Dependencia de datos fuente:**
   - El modelo depende de `s__traffic__session__event` que está en carga incremental histórica.
   - **Impacto:** Si los datos fuente están desactualizados, las métricas también lo estarán.
   - **Recomendación:** Verificar `MAX(base_date)` de `s__traffic__session__event` antes de ejecutar.

3. **Recálculo completo en incremental:**
   - Cuando una tienda tiene nuevas sesiones, se recalculan **todas** las métricas (no solo las nuevas).
   - **Razón:** Las ventanas de tiempo (7d, 15d, 30d, etc.) pueden cambiar cuando una tienda pasa de un período a otro.
   - **Impacto:** Puede ser más lento para tiendas con muchas sesiones, pero asegura precisión.

4. **Filtro de usuarios finales:**
   - Solo cuenta sesiones de usuarios finales (`is_end_user = TRUE`).
   - **Impacto:** No incluye sesiones de merchants (dueños de tiendas), bots o tráfico no-humano.
   - **Razón:** Enfoque en tráfico real de clientes potenciales.

### Notas Técnicas

⚠️ **`blocked_fraud_tag` NO se calcula aquí**, se consume en el GOLD final desde `s__lifecycle__store_status__ref`.

---

## 📊 Métricas y KPIs Sugeridos

### Métricas de Engagement
- **Tasa de tiendas con tráfico:** `COUNT(store_sessions_30d > 0) / COUNT(*) * 100`
- **Promedio de sesiones por tienda:** `AVG(store_sessions_30d)`
- **Mediana de sesiones por tienda:** `PERCENTILE(store_sessions_30d, 0.5)`

### Segmentación
- **Tiendas con alto tráfico:** `store_sessions_30d >= 100`
- **Tiendas con tráfico medio:** `store_sessions_30d BETWEEN 10 AND 99`
- **Tiendas con bajo tráfico:** `store_sessions_30d BETWEEN 1 AND 9`
- **Tiendas sin tráfico:** `store_sessions_30d = 0 OR store_sessions_30d IS NULL`

### Análisis Temporal
- **Tiempo hasta primera sesión:** `DATEDIFF(first_store_session, store_created_at)`
- **Crecimiento de sesiones:** `(store_sessions_60d - store_sessions_30d) / store_sessions_30d * 100`

---

## 🐛 Debugging

### Problemas Comunes

#### 1. Modelo no actualiza tiendas existentes
**Síntoma:** Tiendas con nuevas sesiones no aparecen actualizadas.

**Causa posible:** `last_processed_date` no se está actualizando correctamente.

**Solución:**
```sql
-- Verificar last_processed_date
SELECT 
    store_id,
    last_processed_date,
    MAX(base_date) AS max_base_date_source
FROM g__product_marketing__storefront_sessions_store__agg
GROUP BY store_id, last_processed_date
HAVING MAX(base_date) > last_processed_date;
```

#### 2. Contadores inconsistentes
**Síntoma:** `store_sessions_7d > store_sessions_15d`

**Causa posible:** Error en la lógica de `DATEDIFF` o datos corruptos.

**Solución:**
```sql
-- Validar consistencia
SELECT 
    store_id,
    store_sessions_7d,
    store_sessions_15d,
    store_sessions_30d
FROM g__product_marketing__storefront_sessions_store__agg
WHERE store_sessions_7d > store_sessions_15d
   OR store_sessions_15d > store_sessions_30d;
```

#### 3. Sesiones de merchants incluidas
**Síntoma:** Contadores muy altos que incluyen tráfico de merchants.

**Causa posible:** `is_end_user` no está funcionando correctamente en la fuente.

**Solución:**
```sql
-- Verificar is_end_user en fuente
SELECT 
    COUNT(*) AS total_sessions,
    COUNT(CASE WHEN is_end_user = TRUE THEN 1 END) AS end_user_sessions,
    COUNT(CASE WHEN is_end_user = FALSE THEN 1 END) AS merchant_sessions
FROM s__traffic__session__event
WHERE base_date >= CURRENT_DATE - 7;
```

---

## 📝 Changelog

| Fecha | Versión | Cambio | Autor |
|-------|---------|---------|-------|
| 2025-11-07 | 1.0 | Creación inicial del modelo | data-dev-dbt-products |

---

## 👥 Contactos

- **Owner técnico:** jhu.boggio@tiendanube.com
- **Business Owner:** Giselle Galli
- **Dominio:** marketing
- **Fuente SSOT:** `s__traffic__session__event` (Owner: Bárbara Aires)

---

## 📚 Referencias

- **PR #500:** https://github.com/TiendaNube/data-dev-dbt-products/pull/500
- **Modelo relacionado:** `g__product_marketing__admin_access_store__agg` (accesos al admin)
- **Modelo relacionado:** `s__product_marketing__products__ref` (configuración de productos)
- **Dimensión canónica:** `s__attributes__store_core__ref`
- **Fuente SSOT:** `s__traffic__session__event` (Bárbara Aires - Product domain)

---

**Última actualización:** 2025-11-07  
**Versión del documento:** 1.0

