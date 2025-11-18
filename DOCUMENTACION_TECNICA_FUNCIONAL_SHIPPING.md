# Documentación Técnica y Funcional
## Modelo: `s__product_marketing__shipping__ref`

---

## 📋 Resumen Ejecutivo

**Modelo:** `s__product_marketing__shipping__ref`  
**Tipo:** SILVER REF (Data Product)  
**Dominio:** Marketing  
**Granularidad:** Una fila por tienda (`store_id`)  
**Materialización:** INCREMENTAL con estrategia MERGE  
**Ejecución:** Diaria a las 7:00 AM (tag: `daily_7am`)

### Propósito
Este modelo rastrea las métricas de configuración de métodos de envío por tienda durante el proceso de onboarding. Identifica si una tienda ha configurado al menos un carrier (método de envío) activo con opciones activas.

---

## 🎯 Funcionalidad

### Objetivo de Negocio
Medir el progreso de las tiendas en el paso de configuración de métodos de envío durante el onboarding. Este es uno de los pasos críticos para que una tienda pueda comenzar a recibir pedidos y completar ventas.

### Casos de Uso
1. **Tracking de Onboarding:** Identificar qué tiendas han completado la configuración de envíos
2. **Análisis de Conversión:** Medir la tasa de conversión del paso de configuración de shipping
3. **Segmentación:** Segmentar tiendas por estado de configuración de envíos
4. **Alertas:** Identificar tiendas que no han configurado envíos después de X días desde su creación
5. **Análisis de Tiempo:** Medir cuánto tiempo tardan las tiendas en configurar sus primeros carriers

### Definición de "Completo"
Una tienda se considera con **shipping configurado** (`config_shipping = 1`) cuando:
- Existe al menos un carrier (`mwp_shipping_carriers`) con `status = 1` (activo)
- Ese carrier tiene al menos una opción (`mwp_shipping_carriers_options`) con `status = 1` (activa)
- Ambos (carrier y opción) no están borrados (`deleted_at IS NULL`)

---

## 🏗️ Arquitectura Técnica

### Dependencias

#### Fuentes (Sources)
- **`stg_moltres.mwp_shipping_carriers`**
  - **Base de datos:** `hive_metastore.moltres`
  - **Descripción:** Tabla de carriers (métodos de envío) configurados por tienda
  - **Columnas utilizadas:**
    - `id` (para JOIN con options)
    - `store_id`
    - `status` (filtrado: `status = 1` significa carrier activo)
    - `created_at` (fecha de configuración)
    - `deleted_at` (filtrado: `IS NULL` para carriers no borrados)

- **`stg_moltres.mwp_shipping_carriers_options`**
  - **Base de datos:** `hive_metastore.moltres`
  - **Descripción:** Tabla de opciones de configuración para cada carrier
  - **Columnas utilizadas:**
    - `carrier_id` (para JOIN con carriers)
    - `status` (filtrado: `status = 1` significa opción activa)
    - `deleted_at` (filtrado: `IS NULL` para opciones no borradas)

#### Modelos (Refs)
- **`s__attributes__store_core__ref`**
  - **Tipo:** Dimensión canónica de atributos core de tiendas
  - **Uso:** Filtrado de tiendas creadas después de `2024-01-01` y validación de existencia
  - **Columnas utilizadas:**
    - `store_id`
    - `created_at`

### Estructura de Datos

#### Columnas de Salida

| Columna | Tipo | Descripción | Valores Posibles |
|---------|------|-------------|------------------|
| `store_id` | BIGINT | ID único de la tienda | Cualquier `store_id` válido |
| `config_shipping` | INTEGER | Indica si la tienda configuró métodos de envío | `0` = no configurado<br>`1` = configurado |
| `first_date_config_shipping` | TIMESTAMP | Fecha de la primera configuración de carrier activo | `NULL` si no hay carriers activos<br>Timestamp si hay carriers activos |
| `last_date_config_shipping` | TIMESTAMP | Fecha de la última configuración de carrier activo | `NULL` si no hay carriers activos<br>Timestamp si hay carriers activos |
| `sys_audit_created_on` | TIMESTAMP | Timestamp de creación del registro | Timestamp |
| `sys_audit_created_by` | STRING | Identificador del proceso que creó el registro | `'data-dev-dbt-products'` |
| `sys_audit_updated_on` | TIMESTAMP | Timestamp de última actualización | Timestamp |
| `sys_audit_updated_by` | STRING | Identificador del proceso que actualizó el registro | `'data-dev-dbt-products'` |

---

## ⚙️ Lógica de Procesamiento

### Flujo de Datos

```
1. existing_data CTE
   └─> Obtiene datos existentes de la tabla (store_id, audit fields, config_shipping)
       └─> Usa macro get_existing_data()
       └─> Solo en modo incremental (en full-refresh retorna SELECT vacío)

2. last_updated CTE (solo en modo incremental)
   └─> Obtiene el último timestamp de actualización de la tabla
       └─> Usado para detectar cambios recientes en configuraciones de shipping

3. shipping_setup CTE
   └─> JOIN mwp_shipping_carriers (sc) con mwp_shipping_carriers_options (sco)
       └─> Filtros aplicados:
           - sc.status = 1 (carrier activo)
           - sco.status = 1 (opción activa)
           - sc.deleted_at IS NULL (carrier no borrado)
           - sco.deleted_at IS NULL (opción no borrada)
       └─> JOIN con s__attributes__store_core__ref (tiendas creadas > 2024-01-01)
       └─> Agrupa por store_id y calcula:
           - first_shipping_config: MIN(sc.created_at)
           - last_shipping_config: MAX(sc.created_at)

4. SELECT Final
   └─> LEFT JOIN shipping_setup con s__attributes__store_core__ref
   └─> LEFT JOIN existing_data para preservar audit fields
   └─> Calcula config_shipping: 1 si existe en shipping_setup, 0 si no
   └─> Aplica filtros incrementales (si aplica)
   └─> GROUP BY store_id
   └─> HAVING (solo incremental): procesa tiendas nuevas o sin shipping con cambios recientes
```

### Lógica de Agregación

#### `config_shipping`
```sql
MAX(CASE
    WHEN ss.store_id IS NOT NULL THEN 1
    ELSE 0
END) AS config_shipping
```
- **Explicación:** Si existe un registro en `shipping_setup` para esa tienda, significa que tiene al menos un carrier activo con opciones activas, por lo tanto `config_shipping = 1`. Si no existe, `config_shipping = 0`.
- **Uso de MAX():** Necesario porque estamos en contexto de `GROUP BY store_id` y `ss.store_id` viene de un LEFT JOIN.

#### Fechas de Configuración
```sql
MAX(ss.first_shipping_config) AS first_date_config_shipping,
MAX(ss.last_shipping_config) AS last_date_config_shipping
```
- **Explicación:** Toma la primera y última fecha de configuración de carriers activos. Si no hay carriers activos, estas columnas serán `NULL`.
- **Uso de MAX():** Necesario porque estamos en contexto de `GROUP BY store_id` y las columnas vienen de un LEFT JOIN.

#### Campos de Auditoría
```sql
ANY_VALUE(COALESCE(ed.sys_audit_created_on, current_timestamp)) AS sys_audit_created_on,
ANY_VALUE(COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products')) AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
```
- **Explicación:** 
  - `sys_audit_created_on/by`: Preserva los valores originales si el registro ya existe (usando `existing_data`), o usa valores nuevos si es un registro nuevo.
  - `sys_audit_updated_on/by`: Siempre se actualiza con el timestamp y usuario actuales.
- **Uso de ANY_VALUE():** Necesario porque `ed` viene de un LEFT JOIN y estamos en contexto de `GROUP BY store_id`. Como cada `store_id` tiene solo un registro en `existing_data`, `ANY_VALUE()` es semánticamente correcto.

---

## 🔄 Lógica Incremental

### Modo Full-Refresh (Primera Ejecución)

**Comportamiento:**
- Procesa todas las tiendas creadas después de `2024-01-01`
- No usa `existing_data` (retorna SELECT vacío)
- No usa `last_updated` (no se ejecuta)
- No aplica filtros en `WHERE` ni `HAVING` relacionados con incrementales

**Cuándo usar:**
- Primera ejecución del modelo
- Reset completo de datos
- Corrección de datos históricos

### Modo Incremental (Ejecuciones Subsecuentes)

**Comportamiento:**
El modelo procesa dos tipos de tiendas:

1. **Tiendas nuevas** (no existen en la tabla):
   - `ed.store_id IS NULL` (en WHERE)
   - `ANY_VALUE(ed.store_id) IS NULL` (en HAVING)
   - Se insertan en la tabla

2. **Tiendas existentes sin shipping configurado** (`config_shipping = 0`) con cambios recientes:
   - `COALESCE(ed.config_shipping, 0) = 0` (en WHERE)
   - `COALESCE(ANY_VALUE(ed.config_shipping), 0) = 0` (en HAVING)
   - `COALESCE(MAX(ss.last_shipping_config), TIMESTAMP '1900-01-01') > max_updated_on` (en HAVING)
   - Se actualizan si ahora tienen shipping configurado

**Tiendas NO procesadas:**
- Tiendas existentes que ya tienen `config_shipping = 1` (ya completaron el paso)
- Tiendas existentes sin shipping que no tienen cambios recientes

**Optimización:**
- Solo procesa tiendas nuevas o tiendas que pueden cambiar de estado (0 → 1)
- Evita reprocesar tiendas que ya están completas
- Detecta cambios recientes comparando `last_shipping_config` con `max_updated_on`

---

## 📊 Ejemplos de Consultas

### Consulta 1: Tiendas con Shipping Configurado
```sql
SELECT 
    store_id,
    config_shipping,
    first_date_config_shipping,
    last_date_config_shipping
FROM {{ ref('s__product_marketing__shipping__ref') }}
WHERE config_shipping = 1
ORDER BY first_date_config_shipping DESC;
```

### Consulta 2: Tiendas sin Shipping Configurado (Candidatas para Follow-up)
```sql
SELECT 
    s.store_id,
    s.created_at AS store_created_at,
    DATEDIFF(CURRENT_DATE, DATE(s.created_at)) AS days_since_creation,
    sh.config_shipping
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN {{ ref('s__product_marketing__shipping__ref') }} sh
    ON s.store_id = sh.store_id
WHERE s.created_at > '2024-01-01'
    AND (sh.config_shipping = 0 OR sh.config_shipping IS NULL)
    AND DATEDIFF(CURRENT_DATE, DATE(s.created_at)) >= 7
ORDER BY days_since_creation DESC;
```

### Consulta 3: Tiempo Promedio para Configurar Shipping
```sql
SELECT 
    AVG(DATEDIFF(DATE(sh.first_date_config_shipping), DATE(s.created_at))) AS avg_days_to_configure_shipping,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DATEDIFF(DATE(sh.first_date_config_shipping), DATE(s.created_at))) AS median_days_to_configure_shipping
FROM {{ ref('s__attributes__store_core__ref') }} s
INNER JOIN {{ ref('s__product_marketing__shipping__ref') }} sh
    ON s.store_id = sh.store_id
WHERE s.created_at > '2024-01-01'
    AND sh.config_shipping = 1
    AND sh.first_date_config_shipping IS NOT NULL;
```

### Consulta 4: Tasa de Conversión de Shipping por Mes
```sql
SELECT 
    DATE_TRUNC('month', s.created_at) AS store_creation_month,
    COUNT(DISTINCT s.store_id) AS total_stores,
    COUNT(DISTINCT CASE WHEN sh.config_shipping = 1 THEN s.store_id END) AS stores_with_shipping,
    ROUND(
        COUNT(DISTINCT CASE WHEN sh.config_shipping = 1 THEN s.store_id END) * 100.0 / 
        COUNT(DISTINCT s.store_id), 
        2
    ) AS conversion_rate_pct
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN {{ ref('s__product_marketing__shipping__ref') }} sh
    ON s.store_id = sh.store_id
WHERE s.created_at > '2024-01-01'
GROUP BY DATE_TRUNC('month', s.created_at)
ORDER BY store_creation_month DESC;
```

---

## ✅ Validaciones y Tests

### Tests de Calidad de Datos

| Test | Columna | Descripción |
|------|---------|-------------|
| `not_null` | `store_id` | Garantiza que todas las filas tengan un `store_id` |
| `unique` | `store_id` | Garantiza que no haya duplicados por `store_id` |
| `not_null` | `config_shipping` | Garantiza que todas las filas tengan un valor de configuración |
| `accepted_values` | `config_shipping` | Valida que solo contenga valores `0` o `1` |

### Validaciones Manuales Recomendadas

1. **Consistencia de fechas:**
   - `first_date_config_shipping <= last_date_config_shipping` (si ambos no son NULL)
   - `first_date_config_shipping` y `last_date_config_shipping` deben ser >= `2024-01-01`

2. **Consistencia de estado:**
   - Si `config_shipping = 1`, entonces `first_date_config_shipping` y `last_date_config_shipping` NO deben ser NULL
   - Si `config_shipping = 0`, entonces `first_date_config_shipping` y `last_date_config_shipping` pueden ser NULL

3. **Auditoría:**
   - `sys_audit_created_on <= sys_audit_updated_on`
   - `sys_audit_created_by` y `sys_audit_updated_by` deben ser `'data-dev-dbt-products'`

4. **Integridad referencial:**
   - Todos los `store_id` deben existir en `s__attributes__store_core__ref`
   - Todos los `store_id` con `config_shipping = 1` deben tener al menos un carrier activo en las fuentes

---

## 🚀 Ejecución y Mantenimiento

### Comandos de Validación

```bash
# Full refresh (primera ejecución o reset completo)
dbt build --select s__product_marketing__shipping__ref --full-refresh

# Ejecución incremental (ejecución normal)
dbt build --select s__product_marketing__shipping__ref

# Validación de documentación
dbt run-operation required_docs

# Compilación (sin ejecutar)
dbt compile --select s__product_marketing__shipping__ref
```

### Ejecución en Producción

El modelo se ejecuta automáticamente todos los días a las 7:00 AM mediante el DAG de Airflow:
- **DAG ID:** `dbt_marketing_daily-7am`
- **Tag:** `daily_7am`
- **Frecuencia:** Diaria
- **Estrategia:** Incremental (excepto en primera ejecución)

### Monitoreo

**Métricas a monitorear:**
1. **Tiempo de ejecución:** Debe completarse en < 5 minutos normalmente
2. **Registros procesados:** Comparar con ejecuciones anteriores para detectar anomalías
3. **Tests:** Todos los tests deben pasar (4/4)
4. **Documentación:** El modelo debe estar correctamente documentado (validado con `required_docs`)

**Alertas recomendadas:**
- Falla en ejecución del modelo
- Tests fallando
- Tiempo de ejecución > 10 minutos
- Cambio significativo en número de registros procesados

---

## 🔍 Debugging y Troubleshooting

### Problema: Modelo no actualiza tiendas existentes

**Síntoma:** Tiendas que configuraron shipping no aparecen con `config_shipping = 1`

**Causas posibles:**
1. La lógica incremental está filtrando incorrectamente
2. Los carriers no cumplen los criterios (status != 1 o deleted_at IS NOT NULL)
3. Las opciones de carrier no cumplen los criterios (status != 1 o deleted_at IS NOT NULL)

**Solución:**
```sql
-- Verificar si existen carriers activos para una tienda específica
SELECT 
    sc.store_id,
    sc.id AS carrier_id,
    sc.status AS carrier_status,
    sc.deleted_at AS carrier_deleted_at,
    sco.id AS option_id,
    sco.status AS option_status,
    sco.deleted_at AS option_deleted_at,
    sc.created_at
FROM {{ source('stg_moltres', 'mwp_shipping_carriers') }} sc
INNER JOIN {{ source('stg_moltres', 'mwp_shipping_carriers_options') }} sco
    ON sc.id = sco.carrier_id
WHERE sc.store_id = <store_id_a_verificar>
    AND sc.status = 1
    AND sco.status = 1
    AND sc.deleted_at IS NULL
    AND sco.deleted_at IS NULL;
```

### Problema: Fechas de configuración son NULL cuando config_shipping = 1

**Síntoma:** `config_shipping = 1` pero `first_date_config_shipping` y `last_date_config_shipping` son NULL

**Causa:** Error en la lógica de agregación o en el JOIN con `shipping_setup`

**Solución:**
- Verificar que el CTE `shipping_setup` esté retornando datos correctamente
- Verificar que el LEFT JOIN con `shipping_setup` esté funcionando correctamente

### Problema: Tests fallando

**Síntoma:** Tests de `not_null`, `unique`, o `accepted_values` fallan

**Soluciones:**
- `not_null store_id`: Verificar que todas las tiendas en `s__attributes__store_core__ref` tengan `store_id` válido
- `unique store_id`: Verificar que no haya duplicados en el GROUP BY
- `accepted_values config_shipping`: Verificar que solo haya valores 0 o 1

---

## 📝 Notas Técnicas

### Decisión de Diseño: LEFT JOIN vs INNER JOIN

**Decisión:** Se usa `LEFT JOIN` entre `s__attributes__store_core__ref` y `shipping_setup`

**Razón:** Queremos tener una fila para TODAS las tiendas (creadas después de 2024-01-01), incluso si no han configurado shipping. Esto permite:
- Segmentar tiendas por estado de configuración
- Calcular tasas de conversión
- Identificar tiendas que necesitan follow-up

### Decisión de Diseño: Filtro de Fecha (2024-01-01)

**Decisión:** Solo procesa tiendas creadas después de `2024-01-01`

**Razón:** 
- Limitar el scope a tiendas recientes
- Evitar procesar datos históricos que pueden tener inconsistencias
- Alinear con otros modelos de onboarding que usan el mismo filtro

### Decisión de Diseño: status = 1

**Decisión:** Solo considera carriers y opciones con `status = 1` como "activos"

**Razón:**
- `status = 1` significa que el carrier/opción está activo y disponible para uso
- Evita considerar configuraciones que están desactivadas o en estado de prueba

### Decisión de Diseño: Preservación de Audit Fields

**Decisión:** Se preservan `sys_audit_created_on` y `sys_audit_created_by` de la primera carga

**Razón:**
- Mantener trazabilidad de cuándo y por quién fue creado el registro
- Solo `sys_audit_updated_on/by` se actualizan en cada ejecución

---

## 🔗 Referencias

- **Modelo relacionado:** `s__product_marketing__payments__ref` (configuración de pagos)
- **Modelo relacionado:** `s__product_marketing__layout__ref` (configuración de layout)
- **Dimensión canónica:** `s__attributes__store_core__ref`
- **Deuda técnica:** Este modelo será sustituido por `s__attributes__store_identity__ref` cuando esté disponible

---

## 👥 Contactos

- **Owner técnico:** jhu.boggio@tiendanube.com
- **Business owner:** Giselle Galli
- **Domain:** Marketing

---

**Última actualización:** 2025-11-05  
**Versión del documento:** 1.0


