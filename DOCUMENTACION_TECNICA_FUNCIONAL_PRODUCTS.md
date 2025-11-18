# Documentación Técnica y Funcional
## Modelo: `s__product_marketing__products__ref`

---

## 📋 Resumen Ejecutivo

**Modelo:** `s__product_marketing__products__ref`  
**Tipo:** SILVER REF (Data Product)  
**Dominio:** Marketing  
**Granularidad:** Una fila por tienda (`store_id`)  
**Materialización:** INCREMENTAL con estrategia MERGE  
**Ejecución:** Diaria a las 7:00 AM (tag: `daily_7am`)

### Propósito
Este modelo rastrea las métricas de configuración de productos por tienda durante el proceso de onboarding. Identifica si una tienda ha configurado al menos 6 productos válidos (con descripción y al menos 1 imagen asociada).

---

## 🎯 Funcionalidad

### Objetivo de Negocio
Medir el progreso de las tiendas en el paso de configuración de productos durante el onboarding. Este es uno de los pasos críticos para que una tienda pueda comenzar a operar, ya que necesita tener un catálogo mínimo de productos para recibir pedidos.

### Casos de Uso
1. **Tracking de Onboarding:** Identificar qué tiendas han completado la configuración de productos (6+ productos válidos)
2. **Análisis de Conversión:** Medir la tasa de conversión del paso de configuración de productos
3. **Segmentación:** Segmentar tiendas por estado de configuración de productos
4. **Alertas:** Identificar tiendas que no han configurado productos después de X días desde su creación
5. **Análisis de Tiempo:** Medir cuánto tiempo tarda una tienda en alcanzar los 6 productos válidos

### Definición de "Completo"
Una tienda se considera con **productos configurados** (`config_products = 1`) cuando:
- Tiene al menos **6 productos válidos** que cumplan:
  - `has_description = 1` (producto tiene descripción en `mwp_product_list_i18n`)
  - Al menos **1 imagen asociada** (existe registro en `mwp_product_images`)
  - Producto no está eliminado (`deleted_at IS NULL`)

### Definición de "Producto Válido"
Un producto se considera válido cuando cumple TODAS las siguientes condiciones:
1. Existe en `mwp_product_list` con `deleted_at IS NULL`
2. Tiene descripción: `has_description = 1` en `mwp_product_list_i18n`
3. Tiene al menos 1 imagen: `COUNT(DISTINCT img.id) > 0` en `mwp_product_images`

---

## 🏗️ Arquitectura Técnica

### Dependencias

#### Fuentes (Sources)
- **`stg_catalog.mwp_product_list`**
  - **Base de datos:** `hive_metastore.catalog`
  - **Descripción:** Lista de productos por tienda
  - **Columnas utilizadas:**
    - `store_id` (ID de la tienda)
    - `id` (ID del producto)
    - `created_at` (fecha de creación del producto)
    - `deleted_at` (fecha de eliminación, NULL si está activo)

- **`stg_catalog.mwp_product_list_i18n`**
  - **Base de datos:** `hive_metastore.catalog`
  - **Descripción:** Información internacionalizada de productos (descripciones)
  - **Columnas utilizadas:**
    - `product_id` (ID del producto)
    - `has_description` (1 si tiene descripción, 0 si no)

- **`stg_catalog.mwp_product_images`**
  - **Base de datos:** `hive_metastore.catalog`
  - **Descripción:** Imágenes asociadas a productos
  - **Columnas utilizadas:**
    - `product_id` (ID del producto)
    - `id` (ID de la imagen, usado para contar)

#### Modelos dbt (Refs)
- **`s__attributes__store_core__ref`**
  - **Descripción:** Dimensión canónica de atributos core de tiendas
  - **Uso:** Filtrar solo tiendas creadas después de 2024-01-01
  - **Columnas utilizadas:**
    - `store_id`
    - `created_at` (fecha de creación de la tienda)

---

## 📊 Estructura de Datos

### Tabla de Salida

**Schema:** `data_products_dev.testing_marketing.s__product_marketing__products__ref`  
**Granularidad:** Una fila por `store_id`

### Columnas

| Columna | Tipo | Descripción | Ejemplo |
|---------|------|-------------|---------|
| `store_id` | BIGINT | ID único de la tienda (PK) | `123456` |
| `config_products` | INTEGER | Indica si la tienda configuró productos<br>**1** = configurado (6+ productos válidos)<br>**0** = no configurado | `1` |
| `first_date_config_products` | TIMESTAMP | Fecha del primer producto válido creado | `2024-10-15 10:30:00` |
| `last_date_config_products` | TIMESTAMP | Fecha del sexto producto válido (completitud) si tiene 6+<br>Si tiene menos de 6, fecha del último producto válido | `2024-10-20 14:45:00` |
| `sys_audit_created_on` | TIMESTAMP | Timestamp de creación del registro en el warehouse | `2024-10-15 08:00:00` |
| `sys_audit_created_by` | STRING | Identificador del proceso que creó el registro | `data-dev-dbt-products` |
| `sys_audit_updated_on` | TIMESTAMP | Timestamp de última actualización del registro | `2024-10-20 08:00:00` |
| `sys_audit_updated_by` | STRING | Identificador del proceso que actualizó el registro | `data-dev-dbt-products` |

---

## ⚙️ Lógica de Procesamiento

### Flujo de Datos

```
1. s__attributes__store_core__ref (tiendas desde 2024-01-01)
   ↓
2. mwp_product_list (productos no eliminados)
   ↓
3. LEFT JOIN mwp_product_list_i18n (verificar has_description = 1)
   ↓
4. LEFT JOIN mwp_product_images (contar imágenes)
   ↓
5. valid_products CTE (productos con descripción Y al menos 1 imagen)
   ↓
6. products_setup CTE (agregación por tienda + identificación del 6to producto)
   ↓
7. LEFT JOIN existing_data (preservar auditoría)
   ↓
8. SELECT final con lógica incremental
```

### CTEs (Common Table Expressions)

#### 1. `existing_data`
```sql
{{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by', 'config_products']) }}
```
- **Propósito:** Obtener datos existentes para preservar columnas de auditoría
- **Columnas:** `store_id`, `sys_audit_created_on`, `sys_audit_created_by`, `config_products`

#### 2. `last_updated` (solo en modo incremental)
```sql
SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS max_updated_on
FROM {{ this }}
```
- **Propósito:** Obtener la última fecha de actualización para filtrar cambios recientes
- **Uso:** Filtrar tiendas con productos nuevos desde la última ejecución

#### 3. `valid_products`
```sql
SELECT
    p.store_id,
    p.id AS product_id,
    p.created_at,
    MAX(CASE WHEN i18n.has_description = 1 THEN 1 ELSE 0 END) AS has_desc,
    COUNT(DISTINCT img.id) AS img_count
FROM mwp_product_list p
LEFT JOIN mwp_product_list_i18n i18n ON p.id = i18n.product_id
LEFT JOIN mwp_product_images img ON p.id = img.product_id
WHERE p.deleted_at IS NULL
GROUP BY p.store_id, p.id, p.created_at
HAVING MAX(CASE WHEN i18n.has_description = 1 THEN 1 ELSE 0 END) = 1 
    AND COUNT(DISTINCT img.id) > 0
```
- **Propósito:** Identificar productos válidos (con descripción Y al menos 1 imagen)
- **Filtros:**
  - `p.deleted_at IS NULL` (producto no eliminado)
  - `has_description = 1` (tiene descripción)
  - `COUNT(DISTINCT img.id) > 0` (tiene al menos 1 imagen)

#### 4. `products_setup`
```sql
SELECT
    store_id,
    COUNT(*) AS valid_product_count,
    MIN(created_at) AS first_valid_product_date,
    MAX(created_at) AS last_valid_product_date,
    MAX(CASE WHEN row_num = 6 THEN created_at ELSE NULL END) AS sixth_product_date
FROM (
    SELECT
        store_id,
        created_at,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY created_at) AS row_num
    FROM valid_products
) ranked
GROUP BY store_id
```
- **Propósito:** Agregar productos válidos por tienda e identificar el 6to producto
- **Lógica:**
  - `ROW_NUMBER()` ordena productos por fecha de creación
  - `sixth_product_date` captura la fecha del 6to producto (fecha de completitud)
  - Si tiene menos de 6 productos, `sixth_product_date` será NULL

### Lógica Incremental

#### Modo Full Refresh
- Procesa todas las tiendas creadas después de 2024-01-01

#### Modo Incremental
- **Filtro WHERE:**
  ```sql
  WHERE (
      ed.store_id IS NULL  -- Tiendas nuevas (no existen en tabla)
      OR COALESCE(ed.config_products, 0) = 0  -- Tiendas sin productos configurados
  )
  ```
- **Filtro HAVING:**
  ```sql
  HAVING 
      ANY_VALUE(ed.store_id) IS NULL  -- Tiendas nuevas
      OR (
          COALESCE(ANY_VALUE(ed.config_products), 0) = 0  -- Sin productos configurados
          AND COALESCE(MAX(ps.last_valid_product_date), TIMESTAMP '1900-01-01') > max_updated_on  -- Con productos nuevos
      )
  ```

**Optimización:** Solo procesa:
1. Tiendas nuevas (no existen en la tabla)
2. Tiendas existentes que aún no tienen productos configurados (`config_products = 0`) Y tienen productos nuevos desde la última ejecución

**Nota:** Una vez que una tienda alcanza `config_products = 1`, ya no se procesa en ejecuciones incrementales (a menos que se haga full refresh).

---

## 📝 Ejemplos de Consultas

### Consulta 1: Tiendas con productos configurados
```sql
SELECT 
    store_id,
    config_products,
    first_date_config_products,
    last_date_config_products,
    DATEDIFF(DAY, first_date_config_products, last_date_config_products) AS days_to_complete
FROM `data_products_dev`.`testing_marketing`.`s__product_marketing__products__ref`
WHERE config_products = 1
ORDER BY last_date_config_products DESC
LIMIT 100;
```

### Consulta 2: Tasa de conversión de productos
```sql
SELECT 
    COUNT(*) AS total_tiendas,
    SUM(config_products) AS tiendas_con_productos,
    ROUND(SUM(config_products) * 100.0 / COUNT(*), 2) AS tasa_conversion_pct
FROM `data_products_dev`.`testing_marketing`.`s__product_marketing__products__ref`;
```

### Consulta 3: Tiempo promedio para alcanzar 6 productos
```sql
SELECT 
    AVG(DATEDIFF(DAY, first_date_config_products, last_date_config_products)) AS dias_promedio,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DATEDIFF(DAY, first_date_config_products, last_date_config_products)) AS mediana_dias
FROM `data_products_dev`.`testing_marketing`.`s__product_marketing__products__ref`
WHERE config_products = 1
  AND first_date_config_products IS NOT NULL
  AND last_date_config_products IS NOT NULL;
```

### Consulta 4: Tiendas sin productos después de X días
```sql
SELECT 
    s.store_id,
    s.created_at AS store_created_at,
    p.config_products,
    DATEDIFF(DAY, s.created_at, CURRENT_DATE()) AS dias_desde_creacion
FROM `data_products_dev`.`testing_merchant`.`s__attributes__store_core__ref` s
LEFT JOIN `data_products_dev`.`testing_marketing`.`s__product_marketing__products__ref` p
    ON s.store_id = p.store_id
WHERE s.created_at > '2024-01-01'
  AND COALESCE(p.config_products, 0) = 0
  AND DATEDIFF(DAY, s.created_at, CURRENT_DATE()) >= 30  -- 30 días sin productos
ORDER BY s.created_at DESC;
```

---

## ✅ Validaciones y Tests

### Tests Automáticos (definidos en `marketing__schema.yml`)

1. **`store_id`:**
   - `not_null`: El `store_id` no puede ser NULL
   - `unique`: Cada `store_id` debe ser único (una fila por tienda)

2. **`config_products`:**
   - `not_null`: El campo no puede ser NULL
   - `accepted_values`: Solo acepta valores `0` o `1`

### Validaciones Manuales Recomendadas

1. **Consistencia de fechas:**
   ```sql
   SELECT store_id
   FROM s__product_marketing__products__ref
   WHERE first_date_config_products > last_date_config_products;
   -- Debe retornar 0 filas
   ```

2. **Lógica de completitud:**
   ```sql
   SELECT store_id, config_products, last_date_config_products
   FROM s__product_marketing__products__ref
   WHERE config_products = 1
     AND last_date_config_products IS NULL;
   -- Debe retornar 0 filas (si config_products = 1, debe tener fecha)
   ```

3. **Integridad con store_core:**
   ```sql
   SELECT p.store_id
   FROM s__product_marketing__products__ref p
   LEFT JOIN s__attributes__store_core__ref s
       ON p.store_id = s.store_id
   WHERE s.store_id IS NULL;
   -- Debe retornar 0 filas (todas las tiendas deben existir en store_core)
   ```

---

## 🚀 Ejecución y Mantenimiento

### Comandos de Ejecución

#### Full Refresh (primera ejecución o reprocesamiento completo)
```bash
cd nubeproduct
dbt build --select s__product_marketing__products__ref --full-refresh
```

#### Ejecución Incremental (ejecución normal)
```bash
cd nubeproduct
dbt build --select s__product_marketing__products__ref
```

#### Solo Compilar (validar sintaxis)
```bash
cd nubeproduct
dbt compile --select s__product_marketing__products__ref
```

#### Ejecutar Tests
```bash
cd nubeproduct
dbt test --select s__product_marketing__products__ref
```

### Frecuencia de Ejecución
- **Programado:** Diario a las 7:00 AM (tag: `daily_7am`)
- **Orquestación:** Airflow DAG `dbt_marketing_daily-7am`

### Mantenimiento

#### Cuándo hacer Full Refresh
1. **Cambios en la lógica del modelo:** Si se modifica la definición de "producto válido" o el umbral de 6 productos
2. **Corrección de datos:** Si se detectan inconsistencias en los datos históricos
3. **Primera ejecución:** Siempre hacer full refresh la primera vez

#### Monitoreo
- Verificar que el número de tiendas con `config_products = 1` aumente gradualmente
- Monitorear el tiempo de ejecución (debe ser < 5 minutos en modo incremental)
- Alertar si hay tiendas que no se actualizan después de varios días

---

## 🐛 Debugging

### Problema: Tienda tiene productos pero `config_products = 0`

**Verificación:**
```sql
-- Ver productos de la tienda
SELECT 
    p.id AS product_id,
    p.created_at,
    MAX(CASE WHEN i18n.has_description = 1 THEN 1 ELSE 0 END) AS has_desc,
    COUNT(DISTINCT img.id) AS img_count
FROM `hive_metastore`.`catalog`.`mwp_product_list` p
LEFT JOIN `hive_metastore`.`catalog`.`mwp_product_list_i18n` i18n
    ON p.id = i18n.product_id
LEFT JOIN `hive_metastore`.`catalog`.`mwp_product_images` img
    ON p.id = img.product_id
WHERE p.store_id = <STORE_ID>
  AND p.deleted_at IS NULL
GROUP BY p.id, p.created_at
HAVING MAX(CASE WHEN i18n.has_description = 1 THEN 1 ELSE 0 END) = 1 
    AND COUNT(DISTINCT img.id) > 0;
```

**Posibles causas:**
- Productos sin descripción (`has_description = 0`)
- Productos sin imágenes
- Menos de 6 productos válidos

### Problema: `last_date_config_products` es NULL cuando `config_products = 1`

**Causa:** Error en la lógica de identificación del 6to producto

**Solución:** Verificar que `products_setup` CTE esté identificando correctamente el 6to producto con `ROW_NUMBER()`

### Problema: Tienda no se actualiza en modo incremental

**Verificación:**
```sql
-- Verificar si la tienda está en la tabla
SELECT * 
FROM s__product_marketing__products__ref
WHERE store_id = <STORE_ID>;

-- Verificar si tiene productos nuevos
SELECT MAX(created_at) AS last_product_date
FROM valid_products
WHERE store_id = <STORE_ID>;
```

**Posibles causas:**
- La tienda ya tiene `config_products = 1` (no se procesa en incremental)
- No hay productos nuevos desde la última ejecución
- La tienda no está en `s__attributes__store_core__ref`

---

## 📌 Notas Técnicas

### Lógica del 6to Producto
- Se usa `ROW_NUMBER()` para ordenar productos por fecha de creación
- El 6to producto se identifica cuando `row_num = 6`
- `last_date_config_products` captura la fecha del 6to producto (fecha de completitud)
- Si tiene menos de 6 productos, `last_date_config_products` será la fecha del último producto válido

### Optimización Incremental
- El modelo solo procesa tiendas nuevas o tiendas sin productos configurados
- Una vez que `config_products = 1`, la tienda no se procesa en ejecuciones incrementales
- Esto reduce significativamente el tiempo de ejecución

### Agregaciones con JOINs
- Se usan `MAX()` y `ANY_VALUE()` en el SELECT final porque estamos en contexto `GROUP BY` con columnas de JOINs
- Esto es necesario para cumplir con las reglas de SQL para agregaciones

### Filtro de Fecha
- Solo procesa tiendas creadas después de `2024-01-01`
- Esto limita el alcance del modelo a tiendas recientes

---

## 📊 Métricas Sugeridas

### Métricas de Onboarding
1. **Tasa de Completitud de Productos:**
   - `SUM(config_products) / COUNT(*) * 100`
   - Porcentaje de tiendas que alcanzaron 6+ productos válidos

2. **Tiempo Promedio para Completar:**
   - `AVG(DATEDIFF(DAY, first_date_config_products, last_date_config_products))`
   - Días promedio desde el primer producto hasta el 6to

3. **Distribución de Tiempo:**
   - Percentiles (P25, P50, P75, P90) del tiempo para completar

### Métricas de Segmentación
1. **Tiendas por Estado:**
   - `config_products = 0` vs `config_products = 1`
   - Por país, plan, vertical, etc.

2. **Tiendas Estancadas:**
   - Tiendas con `config_products = 0` después de X días desde creación

---

## 📝 Changelog

| Fecha | Versión | Cambio | Autor |
|-------|---------|--------|-------|
| 2024-11-07 | 1.0.0 | Creación inicial del modelo | jhu.boggio@tiendanube.com |

---

## 👥 Contactos

- **Owner:** jhu.boggio@tiendanube.com
- **Domain:** marketing
- **Business Owner:** Giselle Galli
- **Data Engineering:** data-dev-dbt-products

---

## ⚠️ Deuda Técnica

Este modelo será sustituido por `s__attributes__store_identity__ref` cuando esté disponible. La nueva dimensión canónica incluirá:
- Contactos, usuario principal, documentos fiscales
- Redes sociales
- Configuraciones de onboarding (layout, products, payments, shipping)

---

## 🔗 Referencias

- **Modelo relacionado:** `s__product_marketing__payments__ref` (configuración de pagos)
- **Modelo relacionado:** `s__product_marketing__shipping__ref` (configuración de envío)
- **Modelo relacionado:** `s__product_marketing__layout__ref` (configuración de layout)
- **Dimensión base:** `s__attributes__store_core__ref` (atributos core de tiendas)

