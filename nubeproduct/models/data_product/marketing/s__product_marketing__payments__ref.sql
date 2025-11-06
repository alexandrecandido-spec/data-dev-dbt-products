{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
    )
}}

/*
Data Product: Payments Configuration Metrics (SILVER REF)
Description: Métricas de configuración de métodos de pago por tienda durante el onboarding
Owner: marketing
Domain: product_marketing

Spec: Step completo en la primera ocurrencia del evento 'PaymentProviderRegistered'

✅ Materialización INCREMENTAL:
   - Solo procesa tiendas nuevas desde última ejecución
   - Estrategia MERGE con unique_key=store_id

✅ Fuentes: hive_metastore (raw data), outputs en Unity Catalog (data_marketing)

⚠️ DEUDA TÉCNICA:
   Este modelo será sustituido por s__attributes__store_identity__ref cuando esté disponible.
   La nueva dimensión canónica incluirá: contactos, usuario principal, documentos fiscales, 
   redes sociales y configuraciones de onboarding (layout, products, payments, shipping).
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by', 'config_payment']) }}
),
{% if is_incremental() %}
last_updated AS (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS max_updated_on
    FROM {{ this }}
),
{% endif %}
payment_setup AS (
    SELECT
        CAST(jpps.storeId AS BIGINT) AS store_id,
        MIN(jpps.utcDateTime) AS first_payment_config,
        MAX(jpps.utcDateTime) AS last_payment_config
    FROM {{ source('stg_payments', 'journal_payment_provider') }} jpps
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON CAST(jpps.storeId AS BIGINT) = s.store_id
        AND s.created_at > '2024-01-01'
    WHERE ARRAY_CONTAINS(jpps.event_tg, 'PaymentProviderRegistered')
    GROUP BY CAST(jpps.storeId AS BIGINT)
)

SELECT
    s.store_id,
    -- Pagos configurados
    -- MAX() necesario porque usamos columnas de JOINs en contexto GROUP BY
    MAX(CASE
        WHEN ps.store_id IS NOT NULL THEN 1
        ELSE 0
    END) AS config_payment,
    -- MAX() necesario porque usamos columnas de JOINs en contexto GROUP BY
    MAX(ps.first_payment_config) AS first_date_config_payment,
    MAX(ps.last_payment_config) AS last_date_config_payment,
    
    -- Auditoría
    -- ANY_VALUE() necesario porque ed viene de LEFT JOIN y necesitamos agregar en contexto GROUP BY
    ANY_VALUE(COALESCE(ed.sys_audit_created_on, current_timestamp)) AS sys_audit_created_on,
    ANY_VALUE(COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products')) AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN payment_setup ps ON s.store_id = ps.store_id
LEFT JOIN existing_data ed ON s.store_id = ed.store_id
WHERE s.created_at > '2024-01-01'
{% if is_incremental() %}
    -- Procesar tiendas nuevas (no existen en tabla) o tiendas existentes que NO tienen pagos configurados
    AND (
        ed.store_id IS NULL
        OR COALESCE(ed.config_payment, 0) = 0
    )
{% endif %}
GROUP BY s.store_id
{% if is_incremental() %}
HAVING 
    -- Procesar todas las tiendas nuevas (no existen en tabla)
    -- ANY_VALUE() necesario porque ed viene de LEFT JOIN y necesitamos agregar en contexto GROUP BY
    ANY_VALUE(ed.store_id) IS NULL
    -- O tiendas sin pagos con cambios recientes en configuraciones
    -- MAX() necesario porque estamos en contexto GROUP BY y usamos columnas de JOINs
    OR (
        COALESCE(ANY_VALUE(ed.config_payment), 0) = 0
        AND COALESCE(MAX(ps.last_payment_config), TIMESTAMP '1900-01-01') > (SELECT max_updated_on FROM last_updated)
    )
{% endif %}