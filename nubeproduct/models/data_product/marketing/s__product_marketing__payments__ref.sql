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
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
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
    CASE
        WHEN ps.store_id IS NOT NULL THEN 1
        ELSE 0
    END AS config_payment,
    ps.first_payment_config AS first_date_config_payment,
    ps.last_payment_config AS last_date_config_payment,
    
    -- Auditoría
    COALESCE(ed.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN payment_setup ps ON s.store_id = ps.store_id
LEFT JOIN existing_data ed ON s.store_id = ed.store_id
WHERE s.created_at > '2024-01-01'
{% if is_incremental() %}
    AND s.store_id NOT IN (SELECT store_id FROM {{ this }})
{% endif %}