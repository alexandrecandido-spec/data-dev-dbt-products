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
Data Product: Products Configuration Metrics (SILVER REF)
Description: Métricas de configuración de productos por tienda durante el onboarding
Owner: marketing
Domain: product_marketing

Spec: Step completo cuando la tienda tiene al menos 6 productos válidos con:
  - has_description = 1 (de mwp_product_list_i18n)
  - Al menos 1 imagen asociada (de mwp_product_images)

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
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by', 'config_products']) }}
),
{% if is_incremental() %}
last_updated AS (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS max_updated_on
    FROM {{ this }}
),
{% endif %}
valid_products AS (
    SELECT
        p.store_id,
        p.id AS product_id,
        p.created_at,
        -- Verificar que tenga descripción
        MAX(CASE WHEN i18n.has_description = 1 THEN 1 ELSE 0 END) AS has_desc,
        -- Verificar que tenga al menos 1 imagen
        COUNT(DISTINCT img.id) AS img_count
    FROM {{ source('stg_catalog', 'mwp_product_list') }} p
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON s.store_id = p.store_id
        AND s.created_at > '2024-01-01'
    LEFT JOIN {{ source('stg_catalog', 'mwp_product_list_i18n') }} i18n
        ON p.id = i18n.product_id
    LEFT JOIN {{ source('stg_catalog', 'mwp_product_images') }} img
        ON p.id = img.product_id
    WHERE p.deleted_at IS NULL
    GROUP BY p.store_id, p.id, p.created_at
    HAVING MAX(CASE WHEN i18n.has_description = 1 THEN 1 ELSE 0 END) = 1 
        AND COUNT(DISTINCT img.id) > 0
),
products_setup AS (
    SELECT
        store_id,
        COUNT(*) AS valid_product_count,
        MIN(created_at) AS first_valid_product_date,
        MAX(created_at) AS last_valid_product_date,
        -- Fecha del 6to producto (si existe) - fecha de completitud
        -- Usamos ROW_NUMBER para identificar el 6to producto
        MAX(CASE 
            WHEN row_num = 6 THEN created_at 
            ELSE NULL 
        END) AS sixth_product_date
    FROM (
        SELECT
            store_id,
            created_at,
            ROW_NUMBER() OVER (
                PARTITION BY store_id 
                ORDER BY created_at
            ) AS row_num
        FROM valid_products
    ) ranked
    GROUP BY store_id
)

SELECT
    s.store_id,
    -- Productos configurados: 1 si tiene 6+ productos válidos, 0 si no
    -- MAX() necesario porque usamos columnas de JOINs en contexto GROUP BY
    MAX(CASE
        WHEN ps.store_id IS NOT NULL AND ps.valid_product_count >= 6 THEN 1
        ELSE 0
    END) AS config_products,
    -- Primera fecha = primer producto válido
    -- MAX() necesario porque usamos columnas de JOINs en contexto GROUP BY
    MAX(ps.first_valid_product_date) AS first_date_config_products,
    -- Última fecha = sexto producto (fecha de completitud) si tiene 6+, sino el último producto válido
    -- MAX() necesario porque usamos columnas de JOINs en contexto GROUP BY
    MAX(COALESCE(
        CASE WHEN ps.valid_product_count >= 6 THEN ps.sixth_product_date END,
        ps.last_valid_product_date
    )) AS last_date_config_products,
    
    -- Auditoría
    -- ANY_VALUE() necesario porque ed viene de LEFT JOIN y necesitamos agregar en contexto GROUP BY
    ANY_VALUE(COALESCE(ed.sys_audit_created_on, current_timestamp)) AS sys_audit_created_on,
    ANY_VALUE(COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products')) AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN products_setup ps ON s.store_id = ps.store_id
LEFT JOIN existing_data ed ON s.store_id = ed.store_id
WHERE s.created_at > '2024-01-01'
{% if is_incremental() %}
    -- Procesar tiendas nuevas (no existen en tabla) o tiendas existentes que NO tienen productos configurados
    AND (
        ed.store_id IS NULL
        OR COALESCE(ed.config_products, 0) = 0
    )
{% endif %}
GROUP BY s.store_id
{% if is_incremental() %}
HAVING 
    -- Procesar todas las tiendas nuevas (no existen en tabla)
    -- ANY_VALUE() necesario porque ed viene de LEFT JOIN y necesitamos agregar en contexto GROUP BY
    ANY_VALUE(ed.store_id) IS NULL
    -- O tiendas sin productos configurados con cambios recientes (nuevos productos válidos)
    -- MAX() necesario porque estamos en contexto GROUP BY y usamos columnas de JOINs
    OR (
        COALESCE(ANY_VALUE(ed.config_products), 0) = 0
        AND COALESCE(MAX(ps.last_valid_product_date), TIMESTAMP '1900-01-01') > (SELECT max_updated_on FROM last_updated)
    )
{% endif %}

