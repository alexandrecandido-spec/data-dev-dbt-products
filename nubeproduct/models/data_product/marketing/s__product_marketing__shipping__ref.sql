{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        on_schema_change='fail',
        tags=['daily-7am']
    )
}}

/*
Data Product: Shipping Configuration Metrics (SILVER REF)
Description: Métricas de configuración de métodos de envío por tienda durante el onboarding
Owner: marketing
Domain: product_marketing

Spec: Step completo cuando la tienda activó un carrier con status activo

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
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by', 'config_shipping']) }}
),
{% if is_incremental() %}
last_updated AS (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS max_updated_on
    FROM {{ this }}
),
{% endif %}
shipping_setup AS (
    SELECT
        sc.store_id,
        MIN(sc.created_at) AS first_shipping_config,
        MAX(sc.created_at) AS last_shipping_config
    FROM {{ source('stg_moltres', 'mwp_shipping_carriers') }} sc
    INNER JOIN {{ source('stg_moltres', 'mwp_shipping_carriers_options') }} sco
        ON sc.id = sco.carrier_id
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON s.store_id = sc.store_id
        AND s.created_at > '2024-01-01'
    WHERE sc.status = 1 
        AND sco.status = 1
        AND sc.deleted_at IS NULL
        AND sco.deleted_at IS NULL
    GROUP BY sc.store_id
)

SELECT
    s.store_id,
    -- Envíos configurados
    -- MAX() necesario porque usamos columnas de JOINs en contexto GROUP BY
    MAX(CASE
        WHEN ss.store_id IS NOT NULL THEN 1
        ELSE 0
    END) AS config_shipping,
    -- MAX() necesario porque usamos columnas de JOINs en contexto GROUP BY
    MAX(ss.first_shipping_config) AS first_date_config_shipping,
    MAX(ss.last_shipping_config) AS last_date_config_shipping,
    
    -- Auditoría
    -- ANY_VALUE() necesario porque ed viene de LEFT JOIN y necesitamos agregar en contexto GROUP BY
    ANY_VALUE(COALESCE(ed.sys_audit_created_on, current_timestamp)) AS sys_audit_created_on,
    ANY_VALUE(COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products')) AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN shipping_setup ss ON s.store_id = ss.store_id
LEFT JOIN existing_data ed ON s.store_id = ed.store_id
WHERE s.created_at > '2024-01-01'
{% if is_incremental() %}
    -- Procesar tiendas nuevas (no existen en tabla) o tiendas existentes que NO tienen shipping configurado
    AND (
        ed.store_id IS NULL
        OR COALESCE(ed.config_shipping, 0) = 0
    )
{% endif %}
GROUP BY s.store_id
{% if is_incremental() %}
HAVING 
    -- Procesar todas las tiendas nuevas (no existen en tabla)
    -- ANY_VALUE() necesario porque ed viene de LEFT JOIN y necesitamos agregar en contexto GROUP BY
    ANY_VALUE(ed.store_id) IS NULL
    -- O tiendas sin shipping con cambios recientes en configuraciones
    -- MAX() necesario porque estamos en contexto GROUP BY y usamos columnas de JOINs
    OR (
        COALESCE(ANY_VALUE(ed.config_shipping), 0) = 0
        AND COALESCE(MAX(ss.last_shipping_config), TIMESTAMP '1900-01-01') > (SELECT max_updated_on FROM last_updated)
    )
{% endif %}

