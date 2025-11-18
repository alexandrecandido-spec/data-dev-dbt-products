# Documentación Técnica y Funcional
## Modelo: `g__product_marketing__admin_access_store__agg`

---

## 📋 Resumen Ejecutivo

**Modelo:** `g__product_marketing__admin_access_store__agg`  
**Tipo:** GOLD AGG (Data Product)  
**Dominio:** Marketing  
**Granularidad:** Una fila por tienda (`store_id`)  
**Materialización:** INCREMENTAL con estrategia MERGE  
**Ejecución:** Diaria a las 7:00 AM (tag: `daily_7am`)

### Propósito
Este modelo calcula métricas agregadas de accesos al panel de administración por tienda durante el proceso de onboarding. Cuenta el total de accesos en diferentes ventanas de tiempo (7d, 15d, 30d, 60d) desde la creación de la tienda, proporcionando métricas de engagement con el panel de administración.

---

## 🎯 Funcionalidad

### Objetivo de Negocio
Medir el engagement de los merchants con el panel de administración durante el onboarding. Este modelo proporciona métricas clave para entender qué tan activos son los merchants en la gestión de sus tiendas.

### Casos de Uso
1. **Tracking de Engagement:** Identificar tiendas con alto/bajo uso del panel de administración.
2. **Análisis de Onboarding:** Medir la efectividad del onboarding en términos de adopción del panel.
3. **Segmentación:** Segmentar tiendas por nivel de actividad en el admin (alto, medio, bajo uso).
4. **Alertas:** Identificar tiendas que no acceden al admin después de X días desde su creación.
5. **Análisis de Retención:** Correlacionar accesos al admin con retención y éxito de la tienda.
6. **Optimización de UX:** Identificar puntos de fricción en el proceso de onboarding.

### Definición de "Acceso al Admin"
Un **acceso al admin** se considera válido cuando:
- Es un evento registrado en `mwp_store_access`
- Está asociado a una tienda creada después de `2024-01-01`
- El evento tiene un `created_at` válido

### Fuente Única de Verdad (SSOT)
- **Modelo Staging:** `marketing__product_marketing__admin_access__event`
- **Source Original:** `stg_moltres.mwp_store_access`
- **Descripción:** Modelo staging que filtra y prepara eventos de acceso al admin para consumo en modelos GOLD. Solo incluye accesos de tiendas creadas después de `2024-01-01`.

---

## 🏗️ Arquitectura Técnica

### Dependencias

#### Modelos (Refs)
- **`marketing__product_marketing__admin_access__event`**
  - **Tipo:** STAGING
  - **Owner:** jhu.boggio@tiendanube.com
  - **Descripción:** Eventos de acceso al panel de administración por tienda
  - **Columnas utilizadas:**
    - `store_id`
    - `created_at` (timestamp del acceso)
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
| `qty_admin_access_7d` | BIGINT | Total de accesos al admin en los primeros 7 días desde creación | `0` o mayor |
| `qty_admin_access_15d` | BIGINT | Total de accesos al admin en los primeros 15 días desde creación | `0` o mayor |
| `qty_admin_access_30d` | BIGINT | Total de accesos al admin en los primeros 30 días desde creación | `0` o mayor |
| `qty_admin_access_60d` | BIGINT | Total de accesos al admin en los primeros 60 días desde creación | `0` o mayor |
| `first_date_admin_access` | TIMESTAMP | Fecha y hora del primer acceso al admin | `NULL` si no hay accesos<br>Timestamp si hay accesos |
| `last_date_admin_access` | TIMESTAMP | Fecha y hora del último acceso al admin | `NULL` si no hay accesos<br>Timestamp si hay accesos |
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

2. SELECT principal
   └─> JOIN entre:
       ├─> marketing__product_marketing__admin_access__event (eventos de acceso)
       ├─> s__attributes__store_core__ref (filtro: created_at > '2024-01-01')
       └─> existing_data (para preservar audit fields)
   
3. Agregaciones
   └─> SUM con CASE WHEN para contar accesos por ventana temporal:
       ├─> qty_admin_access_7d: DATEDIFF <= 7 días
       ├─> qty_admin_access_15d: DATEDIFF <= 15 días
       ├─> qty_admin_access_30d: DATEDIFF <= 30 días
       └─> qty_admin_access_60d: DATEDIFF <= 60 días
   
   └─> MIN/MAX para fechas:
       ├─> first_date_admin_access: MIN(created_at)
       └─> last_date_admin_access: MAX(created_at)

4. GROUP BY store_id
   └─> Agrupa todas las métricas por tienda
```

### Lógica Incremental

**Estrategia:** MERGE con `unique_key='store_id'`

**Comportamiento:**
- **Full Refresh:** Procesa todas las tiendas con accesos al admin desde `2024-01-01`
- **Incremental:** Procesa todas las tiendas (nuevas y existentes) sin filtro adicional
  - El MERGE actualiza automáticamente las métricas cuando hay nuevos accesos
  - Las ventanas temporales se recalculan completamente para cada tienda
  - Esto asegura que si una tienda tiene nuevos accesos dentro de una ventana temporal, las métricas se actualizan correctamente

**Ejemplo:**
- Tienda creada el 2024-01-01
- En el día 5: 10 accesos → `qty_admin_access_7d = 10`
- En el día 8: 5 accesos nuevos → `qty_admin_access_7d = 10` (no cambia, fuera de ventana)
- En el día 6: 3 accesos nuevos → `qty_admin_access_7d = 13` (actualiza)

### Agregaciones

**Métricas de Conteo:**
- `qty_admin_access_7d`: Suma de accesos donde `DATEDIFF(DAY, store_created_at, access_created_at) <= 7`
- `qty_admin_access_15d`: Suma de accesos donde `DATEDIFF(DAY, store_created_at, access_created_at) <= 15`
- `qty_admin_access_30d`: Suma de accesos donde `DATEDIFF(DAY, store_created_at, access_created_at) <= 30`
- `qty_admin_access_60d`: Suma de accesos donde `DATEDIFF(DAY, store_created_at, access_created_at) <= 60`

**Métricas de Fechas:**
- `first_date_admin_access`: Primer acceso registrado (MIN)
- `last_date_admin_access`: Último acceso registrado (MAX)

**Nota:** Las ventanas temporales son **inclusivas** y se calculan desde la fecha de creación de la tienda (`s.created_at`).

---

## 📊 Ejemplos de Consultas

### Consulta 1: Tiendas con alto engagement en el admin (primeros 7 días)
```sql
SELECT 
    store_id,
    qty_admin_access_7d,
    first_date_admin_access,
    last_date_admin_access
FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`
WHERE qty_admin_access_7d >= 20
ORDER BY qty_admin_access_7d DESC
LIMIT 100;
```

### Consulta 2: Tiendas sin acceso al admin después de 30 días
```sql
SELECT 
    store_id,
    qty_admin_access_30d,
    first_date_admin_access
FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`
WHERE qty_admin_access_30d = 0
ORDER BY store_id;
```

### Consulta 3: Distribución de accesos por ventana temporal
```sql
SELECT 
    CASE 
        WHEN qty_admin_access_7d = 0 THEN 'Sin acceso'
        WHEN qty_admin_access_7d <= 5 THEN 'Bajo (1-5)'
        WHEN qty_admin_access_7d <= 20 THEN 'Medio (6-20)'
        ELSE 'Alto (21+)'
    END AS engagement_level,
    COUNT(*) AS store_count,
    AVG(qty_admin_access_30d) AS avg_access_30d,
    AVG(qty_admin_access_60d) AS avg_access_60d
FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`
GROUP BY engagement_level
ORDER BY store_count DESC;
```

### Consulta 4: Correlación entre accesos tempranos y accesos a largo plazo
```sql
SELECT 
    CASE 
        WHEN qty_admin_access_7d = 0 THEN 'Sin acceso temprano'
        WHEN qty_admin_access_7d <= 5 THEN 'Bajo acceso temprano'
        ELSE 'Alto acceso temprano'
    END AS early_access_category,
    COUNT(*) AS store_count,
    AVG(qty_admin_access_60d) AS avg_access_60d,
    COUNT(CASE WHEN qty_admin_access_60d > 50 THEN 1 END) * 100.0 / COUNT(*) AS pct_high_engagement_60d
FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`
GROUP BY early_access_category;
```

---

## ✅ Validaciones y Tests

### Tests Automáticos (YAML)

**Tests de Integridad:**
- `not_null` en `store_id`
- `unique` en `store_id`

**Tests de Calidad de Datos:**
- Validación de que `first_date_admin_access <= last_date_admin_access` (si ambos existen)
- Validación de que las métricas de conteo son >= 0

### Validaciones Manuales Recomendadas

1. **Consistencia de Ventanas Temporales:**
   ```sql
   -- Verificar que qty_admin_access_7d <= qty_admin_access_15d <= qty_admin_access_30d <= qty_admin_access_60d
   SELECT COUNT(*) 
   FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`
   WHERE qty_admin_access_7d > qty_admin_access_15d
      OR qty_admin_access_15d > qty_admin_access_30d
      OR qty_admin_access_30d > qty_admin_access_60d;
   -- Debe retornar 0
   ```

2. **Validación de Fechas:**
   ```sql
   -- Verificar que first_date_admin_access <= last_date_admin_access
   SELECT COUNT(*) 
   FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`
   WHERE first_date_admin_access IS NOT NULL 
     AND last_date_admin_access IS NOT NULL
     AND first_date_admin_access > last_date_admin_access;
   -- Debe retornar 0
   ```

3. **Validación de Coherencia con Source:**
   ```sql
   -- Comparar conteo total con source
   SELECT 
       COUNT(DISTINCT store_id) AS stores_in_gold,
       (SELECT COUNT(DISTINCT store_id) 
        FROM `data_products_dev`.`testing_staging`.`marketing__product_marketing__admin_access__event`) AS stores_in_staging
   FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`;
   -- Deben coincidir
   ```

---

## 🚀 Ejecución y Mantenimiento

### Comandos de Ejecución

**Full Refresh:**
```bash
cd nubeproduct
dbt build --select g__product_marketing__admin_access_store__agg --full-refresh
```

**Incremental (default):**
```bash
dbt build --select g__product_marketing__admin_access_store__agg
```

**Solo Tests:**
```bash
dbt test --select g__product_marketing__admin_access_store__agg
```

**Compilar sin ejecutar:**
```bash
dbt compile --select g__product_marketing__admin_access_store__agg
```

### Frecuencia de Ejecución
- **Frecuencia:** Diaria
- **Horario:** 7:00 AM (tag: `daily_7am`)
- **Orquestación:** Airflow DAG `dbt_marketing_daily-7am`

### Monitoreo

**Métricas a Monitorear:**
1. **Tiempo de Ejecución:** Debe ser < 5 minutos en modo incremental
2. **Volumen de Datos:** Número de tiendas procesadas
3. **Calidad:** Porcentaje de tests que pasan
4. **Completitud:** Verificar que todas las tiendas con accesos estén incluidas

**Queries de Monitoreo:**
```sql
-- Verificar última ejecución
SELECT 
    MAX(sys_audit_updated_on) AS last_update,
    COUNT(*) AS total_stores,
    COUNT(CASE WHEN qty_admin_access_7d > 0 THEN 1 END) AS stores_with_access_7d
FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`;
```

---

## ⚠️ Limitaciones y Consideraciones

### Limitaciones

1. **Dependencia de Staging Model:**
   - El modelo depende de `marketing__product_marketing__admin_access__event`
   - Si el staging model falla, este modelo también fallará

2. **Recálculo Completo en Incremental:**
   - En modo incremental, se procesan todas las tiendas (nuevas y existentes)
   - Las métricas se recalculan completamente para cada tienda
   - Esto puede ser costoso en términos de procesamiento para tiendas con muchos accesos

3. **Ventanas Temporales Fijas:**
   - Las ventanas temporales (7d, 15d, 30d, 60d) son fijas
   - No se pueden personalizar sin modificar el modelo

4. **Filtro de Fecha:**
   - Solo incluye tiendas creadas después de `2024-01-01`
   - Tiendas anteriores no aparecerán en el modelo

### Consideraciones

1. **Performance:**
   - El modelo usa `SUM` con `CASE WHEN` para calcular métricas por ventana
   - Para tiendas con muchos accesos, esto puede ser costoso
   - Considerar particionamiento si el volumen crece significativamente

2. **Actualización de Métricas:**
   - Las métricas se actualizan cada vez que hay nuevos accesos
   - Una tienda puede tener `qty_admin_access_7d` que cambia si hay nuevos accesos dentro de la ventana
   - Esto es correcto pero puede ser confuso si se espera que las métricas sean estáticas

3. **NULLs:**
   - `first_date_admin_access` y `last_date_admin_access` pueden ser `NULL` si no hay accesos
   - Las métricas de conteo siempre serán >= 0 (nunca NULL)

---

## 📈 Métricas Sugeridas y KPIs

### Métricas de Engagement

1. **Tasa de Adopción Temprana:**
   - `% de tiendas con qty_admin_access_7d > 0`
   - Mide qué tan rápido los merchants adoptan el panel

2. **Intensidad de Uso:**
   - `Promedio de qty_admin_access_30d por tienda`
   - Mide qué tan activos son los merchants

3. **Retención de Uso:**
   - `% de tiendas con qty_admin_access_60d > qty_admin_access_30d`
   - Mide si los merchants continúan usando el panel después del primer mes

### Segmentación

1. **Alto Engagement:**
   - `qty_admin_access_7d >= 20` o `qty_admin_access_30d >= 50`

2. **Medio Engagement:**
   - `qty_admin_access_7d BETWEEN 5 AND 19` o `qty_admin_access_30d BETWEEN 10 AND 49`

3. **Bajo Engagement:**
   - `qty_admin_access_7d < 5` o `qty_admin_access_30d < 10`

4. **Sin Engagement:**
   - `qty_admin_access_7d = 0` o `qty_admin_access_30d = 0`

### Análisis Temporal

1. **Tiempo hasta Primer Acceso:**
   - `DATEDIFF(DAY, store_created_at, first_date_admin_access)`
   - Mide qué tan rápido los merchants acceden por primera vez

2. **Frecuencia de Acceso:**
   - `qty_admin_access_30d / DATEDIFF(DAY, store_created_at, CURRENT_DATE)`
   - Mide accesos por día en promedio

---

## 🐛 Debugging

### Problemas Comunes

1. **Métricas en 0 para todas las tiendas:**
   - **Causa:** El staging model `marketing__product_marketing__admin_access__event` no tiene datos
   - **Solución:** Verificar que el staging model se ejecute correctamente y tenga datos

2. **Métricas inconsistentes entre ventanas:**
   - **Causa:** Error en la lógica de `DATEDIFF` o en los filtros
   - **Solución:** Verificar que `qty_admin_access_7d <= qty_admin_access_15d <= ...`

3. **Tiendas faltantes:**
   - **Causa:** Filtro `s.created_at > '2024-01-01'` excluye tiendas antiguas
   - **Solución:** Verificar que las tiendas esperadas cumplan el criterio de fecha

### Queries de Debugging

```sql
-- Verificar datos en staging
SELECT 
    COUNT(*) AS total_events,
    COUNT(DISTINCT store_id) AS unique_stores,
    MIN(created_at) AS first_event,
    MAX(created_at) AS last_event
FROM `data_products_dev`.`testing_staging`.`marketing__product_marketing__admin_access__event`;

-- Comparar conteos entre staging y gold
SELECT 
    'staging' AS source,
    COUNT(DISTINCT store_id) AS store_count
FROM `data_products_dev`.`testing_staging`.`marketing__product_marketing__admin_access__event`
UNION ALL
SELECT 
    'gold' AS source,
    COUNT(*) AS store_count
FROM `data_products_dev`.`testing_marketing`.`g__product_marketing__admin_access_store__agg`;
```

---

## 📝 Changelog

| Fecha | Versión | Cambio | Autor |
|-------|---------|--------|-------|
| 2024-11-XX | 1.0.0 | Creación inicial del modelo | jhu.boggio@tiendanube.com |
| 2024-11-XX | 1.1.0 | Actualización para consumir desde staging model `marketing__product_marketing__admin_access__event` | jhu.boggio@tiendanube.com |

---

## 👥 Contactos

**Owner:** jhu.boggio@tiendanube.com  
**Domain Expert:** Giselle Galli  
**Technical Review:** Analytics Engineering Team

---

## 📚 Referencias

- **Staging Model:** `marketing__product_marketing__admin_access__event`
- **Source Original:** `stg_moltres.mwp_store_access`
- **Dimensión Core:** `s__attributes__store_core__ref`
- **Documentación DBT Guide:** `/Users/jhuriamnysboggio/Downloads/Copy_of_DBT_Guide/Copy of DBT Guide.md`

