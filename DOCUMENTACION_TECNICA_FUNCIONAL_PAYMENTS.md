# Documentación Técnica y Funcional
## Modelo: `s__product_marketing__payments__ref`

---

## 📋 Resumen Ejecutivo

**Modelo:** `s__product_marketing__payments__ref`  
**Tipo:** SILVER REF (Data Product)  
**Dominio:** Marketing  
**Granularidad:** Una fila por tienda (`store_id`)  
**Materialización:** INCREMENTAL con estrategia MERGE  
**Ejecución:** Diaria a las 7:00 AM (tag: `daily_7am`)

### Propósito
Este modelo rastrea las métricas de configuración de métodos de pago por tienda durante el proceso de onboarding. Identifica si una tienda ha configurado al menos un método de pago mediante el evento `PaymentProviderRegistered`.

---

## 🎯 Funcionalidad

### Objetivo de Negocio
Medir el progreso de las tiendas en el paso de configuración de métodos de pago durante el onboarding. Este es uno de los pasos críticos para que una tienda pueda comenzar a recibir pedidos.

### Casos de Uso
1. **Tracking de Onboarding:** Identificar qué tiendas han completado la configuración de pagos
2. **Análisis de Conversión:** Medir la tasa de conversión del paso de configuración de pagos
3. **Segmentación:** Segmentar tiendas por estado de configuración de pagos
4. **Alertas:** Identificar tiendas que no han configurado pagos después de X días desde su creación

### Definición de "Completo"
Una tienda se considera con **pagos configurados** (`config_payment = 1`) cuando:
- Existe al menos un evento `PaymentProviderRegistered` en la tabla `journal_payment_provider` para esa tienda

---

## 🏗️ Arquitectura Técnica

### Dependencias

#### Fuentes (Sources)
- **`stg_payments.journal_payment_provider`**
  - **Base de datos:** `hive_metastore.payments`
  - **Descripción:** Journal de eventos de configuración de proveedores de pago
  - **Evento clave:** `PaymentProviderRegistered` (filtrado mediante `ARRAY_CONTAINS(jpps.event_tg, 'PaymentProviderRegistered')`)
  - **Columnas utilizadas:**
    - `storeId` (cast a BIGINT)
    - `utcDateTime` (fecha del evento)
    - `event_tg` (array de eventos)

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
| `config_payment` | INTEGER | Indica si la tienda configuró métodos de pago | `0` = no configurado<br>`1` = configurado |
| `first_date_config_payment` | TIMESTAMP | Fecha del primer evento `PaymentProviderRegistered` | `NULL` si no hay eventos<br>Timestamp si hay eventos |
| `last_date_config_payment` | TIMESTAMP | Fecha del último evento `PaymentProviderRegistered` | `NULL` si no hay eventos<br>Timestamp si hay eventos |
| `sys_audit_created_on` | TIMESTAMP | Timestamp de creación del registro | Timestamp |
| `sys_audit_created_by` | STRING | Identificador del proceso que creó el registro | `'data-dev-dbt-products'` |
| `sys_audit_updated_on` | TIMESTAMP | Timestamp de última actualización | Timestamp |
| `sys_audit_updated_by` | STRING | Identificador del proceso que actualizó el registro | `'data-dev-dbt-products'` |

---

## ⚙️ Lógica de Procesamiento

### Flujo de Datos

```
1. existing_data CTE
   └─> Obtiene datos existentes de la tabla (store_id, audit fields, config_payment)
       └─> Usa macro get_existing_data()

2. last_updated CTE (solo en modo incremental)
   └─> Obtiene el último timestamp de actualización de la tabla
       └─> Usado para detectar cambios recientes

3. payment_setup CTE
   └─> Filtra eventos PaymentProviderRegistered de journal_payment_provider
       └─> JOIN con s__attributes__store_core__ref (tiendas creadas > 2024-01-01)
       └─> Agrupa por store_id y calcula:
           - first_payment_config: MIN(utcDateTime)
           - last_payment_config: MAX(utcDateTime)

4. SELECT Final
   └─> LEFT JOIN payment_setup con s__attributes__store_core__ref
   └─> LEFT JOIN existing_data para preservar audit fields
   └─> Calcula config_payment: 1 si existe en payment_setup, 0 si no
   └─> Aplica filtros incrementales (si aplica)
```

### Lógica Incremental

El modelo usa materialización **INCREMENTAL** con estrategia **MERGE** y `unique_key='store_id'`.

#### Modo Full Refresh
- Procesa **todas** las tiendas creadas después de `2024-01-01`
- No aplica filtros de exclusión

#### Modo Incremental
Procesa **únicamente**:
1. **Tiendas nuevas:** `ed.store_id IS NULL` (no existen en la tabla)
2. **Tiendas sin pagos configurados que tienen cambios recientes:**
   - `COALESCE(ed.config_payment, 0) = 0` (no tienen pagos configurados)
   - `COALESCE(MAX(ps.last_payment_config), TIMESTAMP '1900-01-01') > max_updated_on` (tienen eventos nuevos desde la última ejecución)

**Comportamiento:**
- ✅ **Actualiza** tiendas que cambian de `config_payment = 0` a `config_payment = 1`
- ❌ **NO actualiza** tiendas que ya tienen `config_payment = 1` (incluso si tienen nuevos eventos)
- ✅ **Preserva** campos de auditoría (`sys_audit_created_on`, `sys_audit_created_by`) de la primera carga

### Agregaciones y Funciones SQL

#### Agregaciones en SELECT
- **`MAX(CASE ... END)`** para `config_payment`: Necesario porque estamos en contexto `GROUP BY store_id` y usamos columnas de JOINs
- **`MAX(ps.first_payment_config)`**: Agregación necesaria en contexto `GROUP BY`
- **`MAX(ps.last_payment_config)`**: Agregación necesaria en contexto `GROUP BY`
- **`ANY_VALUE(COALESCE(...))`** para audit fields: Necesario porque `ed` viene de LEFT JOIN y necesitamos agregar en contexto `GROUP BY`

#### Agregaciones en HAVING (solo incremental)
- **`ANY_VALUE(ed.store_id)`**: Para detectar tiendas nuevas
- **`ANY_VALUE(ed.config_payment)`**: Para verificar estado actual
- **`MAX(ps.last_payment_config)`**: Para detectar cambios recientes

---

## 🔍 Ejemplos de Consultas

### Ejemplo 1: Tiendas con pagos configurados
```sql
SELECT 
    store_id,
    config_payment,
    first_date_config_payment,
    last_date_config_payment
FROM {{ ref('s__product_marketing__payments__ref') }}
WHERE config_payment = 1
ORDER BY first_date_config_payment DESC
LIMIT 10;
```

### Ejemplo 2: Tasa de conversión de pagos por mes de creación
```sql
WITH stores AS (
    SELECT 
        store_id,
        DATE_TRUNC('month', created_at) AS creation_month
    FROM {{ ref('s__attributes__store_core__ref') }}
    WHERE created_at > '2024-01-01'
)
SELECT 
    s.creation_month,
    COUNT(DISTINCT s.store_id) AS total_stores,
    COUNT(DISTINCT CASE WHEN p.config_payment = 1 THEN s.store_id END) AS stores_with_payment,
    ROUND(
        COUNT(DISTINCT CASE WHEN p.config_payment = 1 THEN s.store_id END) * 100.0 / 
        COUNT(DISTINCT s.store_id), 
        2
    ) AS conversion_rate_pct
FROM stores s
LEFT JOIN {{ ref('s__product_marketing__payments__ref') }} p
    ON s.store_id = p.store_id
GROUP BY s.creation_month
ORDER BY s.creation_month DESC;
```

### Ejemplo 3: Tiendas sin pagos configurados después de 7 días
```sql
SELECT 
    s.store_id,
    s.created_at AS store_created_at,
    DATEDIFF(CURRENT_DATE, DATE(s.created_at)) AS days_since_creation,
    p.config_payment
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN {{ ref('s__product_marketing__payments__ref') }} p
    ON s.store_id = p.store_id
WHERE s.created_at > '2024-01-01'
    AND (p.config_payment = 0 OR p.config_payment IS NULL)
    AND DATEDIFF(CURRENT_DATE, DATE(s.created_at)) >= 7
ORDER BY days_since_creation DESC;
```

---

## ✅ Validaciones y Tests

### Tests de Calidad de Datos

| Test | Columna | Descripción |
|------|---------|-------------|
| `not_null` | `store_id` | Garantiza que todas las filas tengan un `store_id` |
| `unique` | `store_id` | Garantiza que no haya duplicados por `store_id` |
| `not_null` | `config_payment` | Garantiza que todas las filas tengan un valor de configuración |
| `accepted_values` | `config_payment` | Valida que solo contenga valores `0` o `1` |

### Validaciones Manuales Recomendadas

1. **Consistencia de fechas:**
   - `first_date_config_payment <= last_date_config_payment` (si ambos no son NULL)
   - `first_date_config_payment` y `last_date_config_payment` deben ser >= `2024-01-01`

2. **Consistencia de estado:**
   - Si `config_payment = 1`, entonces `first_date_config_payment` y `last_date_config_payment` NO deben ser NULL
   - Si `config_payment = 0`, entonces `first_date_config_payment` y `last_date_config_payment` pueden ser NULL

3. **Auditoría:**
   - `sys_audit_created_on <= sys_audit_updated_on`
   - `sys_audit_created_by` y `sys_audit_updated_by` deben ser `'data-dev-dbt-products'`

---

## 🚀 Ejecución y Mantenimiento

### Comandos de Validación

```bash
# Full refresh (primera ejecución o reset completo)
dbt build --select s__product_marketing__payments__ref --full-refresh

# Ejecución incremental (ejecución normal)
dbt build --select s__product_marketing__payments__ref

# Validación de documentación
dbt run-operation required_docs

# Compilación (sin ejecutar)
dbt compile --select s__product_marketing__payments__ref
```

### Frecuencia de Ejecución
- **Automática:** Diaria a las 7:00 AM (tag: `daily_7am`)
- **Manual:** Cuando sea necesario actualizar datos históricos o corregir errores

### Monitoreo Recomendado

1. **Volumen de datos:**
   - Verificar que el número de filas aumente gradualmente (solo tiendas nuevas)
   - Alertar si hay un crecimiento anómalo

2. **Calidad:**
   - Monitorear que los tests pasen en cada ejecución
   - Verificar que no haya `store_id` duplicados

3. **Performance:**
   - Monitorear tiempo de ejecución (debe ser < 5 minutos en modo incremental)
   - Alertar si la ejecución tarda más de lo esperado

---

## ⚠️ Limitaciones y Consideraciones

### Limitaciones Conocidas

1. **Filtro de fecha:** Solo procesa tiendas creadas después de `2024-01-01`
   - **Impacto:** Tiendas anteriores a esta fecha no aparecerán en el modelo
   - **Razón:** Optimización de performance y enfoque en tiendas recientes

2. **Actualización de tiendas existentes:**
   - El modelo **SÍ actualiza** tiendas que cambian de `config_payment = 0` a `config_payment = 1`
   - El modelo **NO actualiza** tiendas que ya tienen `config_payment = 1` (incluso si tienen nuevos eventos)
   - **Razón:** Una vez que una tienda tiene pagos configurados, no necesitamos rastrear eventos adicionales

3. **Dependencia de eventos:** El modelo depende de que el evento `PaymentProviderRegistered` esté correctamente registrado en `journal_payment_provider`
   - **Impacto:** Si el evento no se registra, la tienda aparecerá como `config_payment = 0` aunque haya configurado pagos

### Deuda Técnica

⚠️ **Este modelo será sustituido por `s__attributes__store_identity__ref` cuando esté disponible.**

La nueva dimensión canónica incluirá:
- Contactos
- Usuario principal
- Documentos fiscales
- Redes sociales
- Configuraciones de onboarding (layout, products, payments, shipping)

**Acción requerida:** Migrar lógica a la nueva dimensión cuando esté lista.

---

## 📊 Métricas y KPIs Sugeridos

### Métricas de Onboarding
- **Tasa de conversión de pagos:** `COUNT(config_payment = 1) / COUNT(*) * 100`
- **Tiempo promedio hasta configuración:** `AVG(DATEDIFF(first_date_config_payment, store_created_at))`
- **Tiendas sin pagos después de X días:** `COUNT(*) WHERE config_payment = 0 AND days_since_creation >= X`

### Segmentación
- **Tiendas con pagos configurados:** `config_payment = 1`
- **Tiendas sin pagos configurados:** `config_payment = 0`
- **Tiendas con pagos configurados en las últimas 24 horas:** `config_payment = 1 AND first_date_config_payment >= CURRENT_DATE - 1`

---

## 📝 Changelog

| Fecha | Versión | Cambio | Autor |
|-------|---------|---------|-------|
| 2025-11-05 | 1.0 | Creación inicial del modelo | data-dev-dbt-products |
| 2025-11-05 | 1.1 | Optimización de lógica incremental para actualizar tiendas que cambian de 0 a 1 | data-dev-dbt-products |

---

## 👥 Contactos

- **Owner técnico:** jhu.boggio@tiendanube.com
- **Business Owner:** Giselle Galli
- **Dominio:** marketing

---

## 📚 Referencias

- **PR #485:** https://github.com/TiendaNube/data-dev-dbt-products/pull/485
- **Modelo relacionado:** `s__product_marketing__layout__ref` (PR #484)
- **Dimensión canónica:** `s__attributes__store_core__ref`
- **Fuente de datos:** `stg_payments.journal_payment_provider`


