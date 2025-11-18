# Cambios necesarios en los archivos - PR #507

## Archivo: `nubeproduct/models/intermediate/merchant/_int__attributes__store_identity.sql`

### CAMBIO 1: Obtener `main_user_id` desde `merchant__attributes__store_info__ref`

**Líneas 17-26** - Reemplazar el CTE `store_base`:

```sql
-- Información base de la tienda
WITH store_base AS (
    SELECT
        s.store_id,
        si.main_user_id
    FROM {{ ref('s__attributes__store_core__ref') }} s
    LEFT JOIN {{ ref('merchant__attributes__store_info__ref') }} si
        ON s.store_id = si.store_id
    WHERE s.created_at > '2024-01-01'
),
```

**ANTES era:**
```sql
WITH store_base AS (
    SELECT
        s.store_id,
        s.main_user_id
    FROM {{ ref('s__attributes__store_core__ref') }} s
    WHERE s.created_at > '2024-01-01'
),
```

---

### CAMBIO 2: Obtener nombre y descripción desde `mwp_store_settings_i18n` con JOIN

**Líneas 28-42** - Reemplazar el CTE `store_i18n`:

```sql
-- Información i18n de la tienda (nombre y descripción)
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
```

**ANTES era:**
```sql
store_i18n AS (
    SELECT
        store_id,
        store_name,
        store_description
    FROM {{ source('int_moltres', 'mwp_store_settings_i18n') }}
),
```

---

### CAMBIO 3: `mwp_store_settings` - usar `id AS store_id`

**Líneas 44-56** - En el CTE `store_settings`, cambiar la primera línea del SELECT:

```sql
-- Configuración de la tienda (teléfonos, redes sociales)
store_settings AS (
    SELECT
        id AS store_id,
        phone AS phone_from_footer,
        owner_phone_number,
        whatsapp_phone_number AS phone_whatsapp_button,
        CASE
            WHEN owner_phone_number LIKE '+%' THEN owner_phone_number
            WHEN owner_phone_country IS NOT NULL OR owner_phone_area IS NOT NULL OR owner_phone_number IS NOT NULL
            THEN CONCAT('+', COALESCE(owner_phone_country, ''), COALESCE(owner_phone_area, ''), COALESCE(owner_phone_number, ''))
            ELSE NULL
        END AS owner_phone,
        instagram,
        facebook,
        twitter,
        tiktok,
        pinterest
    FROM {{ source('stg_moltres', 'mwp_store_settings') }}
),
```

**ANTES era:**
```sql
store_settings AS (
    SELECT
        store_id,
        phone AS phone_from_footer,
        ...
```

---

### CAMBIO 4: `mwp_invoice_info` - usar staging model en lugar de source

**Líneas 58-65** - Reemplazar el CTE `invoice_info`:

```sql
-- Información de documentos fiscales
invoice_info AS (
    SELECT
        store_id,
        id_type AS doc_type,
        id_number AS doc_number
    FROM {{ ref('moltres__mwp_invoice_info') }}
),
```

**ANTES era:**
```sql
invoice_info AS (
    SELECT
        store_id,
        id_type AS doc_type,
        id_number AS doc_number
    FROM {{ source('stg_moltres', 'mwp_invoice_info') }}
),
```

---

## Archivo: `nubeproduct/models/data_product/merchant/s__attributes__store_identity__ref.sql`

### CAMBIO 5: Tag corregido a `daily-8am-8pm`

**Línea 6** - Cambiar el tag:

```sql
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily-8am-8pm'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE store_id IN (SELECT store_id FROM {{ ref('merchant__attributes__store_info__ref') }} WHERE state = 4)"
        ]
    )
}}
```

**ANTES era:**
```sql
        tags=['daily-10am-10pm'],
```

---

## Resumen de cambios:

1. ✅ **Tag**: `daily-10am-10pm` → `daily-8am-8pm` (ya pusheado)
2. ✅ **main_user_id**: JOIN con `merchant__attributes__store_info__ref`
3. ✅ **store_i18n**: JOIN con `mwp_store_settings` usando `store_setting_id`
4. ✅ **store_settings**: `id AS store_id`
5. ✅ **invoice_info**: `ref('moltres__mwp_invoice_info')` en lugar de `source('stg_moltres', 'mwp_invoice_info')`

