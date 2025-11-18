# Issues encontrados en `s__attributes__store_identity__ref` - PR #507

Hola @ronald.corcho! 

Encontramos varios problemas al ejecutar las pruebas del modelo `s__attributes__store_identity__ref` que requieren ajustes en las fuentes de datos o en la lógica del intermediate. Como este modelo está en el dominio `merchant`, necesitamos tu ayuda para resolverlos.

## Problemas encontrados:

### 1. ✅ **Tag corregido** (ya aplicado)
- **Problema**: El tag estaba como `daily-10am-10pm` pero debía ser `daily-8am-8pm`
- **Estado**: Ya corregido y pusheado

### 2. ⚠️ **`main_user_id` no está en `s__attributes__store_core__ref`**
- **Problema**: El intermediate intentaba obtener `main_user_id` desde `s__attributes__store_core__ref`, pero esa columna no existe ahí
- **Solución temporal aplicada**: Hacemos JOIN con `merchant__attributes__store_info__ref` para obtenerlo
- **Pregunta**: ¿Es correcto obtener `main_user_id` desde `merchant__attributes__store_info__ref` o debería estar en `s__attributes__store_core__ref`?

### 3. ⚠️ **`mwp_invoice_info` source no tiene `store_id`**
- **Problema**: La source directa `stg_moltres.mwp_invoice_info` no tiene columna `store_id` (tiene `id` u otra estructura)
- **Solución temporal aplicada**: Cambiamos a usar el staging model `moltres__mwp_invoice_info` que sí tiene `store_id`
- **Pregunta**: ¿Es correcto usar el staging model o deberíamos usar la source directa con un JOIN diferente?

### 4. ⚠️ **`mwp_store_settings` source tiene `id` no `store_id`**
- **Problema**: La source `stg_moltres.mwp_store_settings` tiene columna `id` no `store_id`
- **Solución temporal aplicada**: Hacemos `id AS store_id` en el SELECT
- **Pregunta**: ¿Es correcto que `id` en `mwp_store_settings` sea el `store_id`?

### 5. ⚠️ **`mwp_store_settings_i18n` no tiene `store_id` directamente**
- **Problema**: La tabla `int_moltres.mwp_store_settings_i18n` no tiene `store_id`, se relaciona con `mwp_store_settings` mediante `store_setting_id`
- **Solución temporal aplicada**: Hacemos JOIN con `mwp_store_settings` usando `ss.id = i18n.store_setting_id` y luego `ss.id AS store_id`
- **Pregunta**: ¿Es correcta esta lógica de JOIN? ¿Hay una forma más directa de obtener el nombre y descripción de la tienda?

## Cambios temporales aplicados en el intermediate:

```sql
-- 1. main_user_id desde merchant__attributes__store_info__ref
WITH store_base AS (
    SELECT
        s.store_id,
        si.main_user_id
    FROM {{ ref('s__attributes__store_core__ref') }} s
    LEFT JOIN {{ ref('merchant__attributes__store_info__ref') }} si
        ON s.store_id = si.store_id
    WHERE s.created_at > '2024-01-01'
),

-- 2. mwp_store_settings_i18n con JOIN
store_i18n AS (
    SELECT
        ss.id AS store_id,
        i18n.name AS store_name,
        i18n.description AS store_description
    FROM {{ source('int_moltres', 'mwp_store_settings') }} ss
    LEFT JOIN {{ source('int_moltres', 'mwp_store_settings_i18n') }} i18n
        ON ss.id = i18n.store_setting_id
    WHERE i18n.id = (
        SELECT MAX(i18n2.id)
        FROM {{ source('int_moltres', 'mwp_store_settings_i18n') }} i18n2
        WHERE i18n2.store_setting_id = ss.id
    )
),

-- 3. mwp_store_settings con id AS store_id
store_settings AS (
    SELECT
        id AS store_id,
        phone AS phone_from_footer,
        ...
    FROM {{ source('stg_moltres', 'mwp_store_settings') }}
),

-- 4. invoice_info desde staging model
invoice_info AS (
    SELECT
        store_id,
        id_type AS doc_type,
        id_number AS doc_number
    FROM {{ ref('moltres__mwp_invoice_info') }}
),
```

## Próximos pasos:

Necesitamos tu confirmación sobre:
1. Si estas soluciones temporales son correctas
2. Si hay mejores formas de obtener estos datos
3. Si necesitamos crear staging models adicionales o ajustar los existentes

El modelo aún no pasa las pruebas debido a estos problemas de estructura de datos. Una vez que confirmes los cambios, podemos proceder con las pruebas finales.

Gracias!
