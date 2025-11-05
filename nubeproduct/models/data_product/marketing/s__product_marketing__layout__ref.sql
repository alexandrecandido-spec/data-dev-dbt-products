{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
    )
}}

/*
Data Product: Layout Configuration Metrics (SILVER REF)
Description: Métricas de configuración de layout/tema por tienda durante el onboarding
Owner: marketing
Domain: product_marketing

Spec: Layout se considera completo cuando la tienda configuró banner, slider Y colors.
La fecha de completitud es la última de las tres configuraciones.

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
banner_config AS (
    SELECT
        opt.store_id,
        MIN(opt.created_at) AS first_banner_date,
        MAX(opt.created_at) AS last_banner_date
    FROM {{ source('stg_moltres', 'mwp_options') }} opt
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON s.store_id = opt.store_id
        AND s.created_at > '2024-01-01'
    WHERE opt.option_name LIKE '%banner_%' 
        AND opt.option_name LIKE 'ls_theme_pvt_setting%'
    GROUP BY opt.store_id
),
slider_config AS (
    SELECT
        opt.store_id,
        MIN(opt.created_at) AS first_slider_date,
        MAX(opt.created_at) AS last_slider_date
    FROM {{ source('stg_moltres', 'mwp_options') }} opt
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON s.store_id = opt.store_id
        AND s.created_at > '2024-01-01'
    WHERE opt.option_name LIKE '%slider%' 
        AND opt.option_name LIKE 'ls_theme_pvt_setting%'
    GROUP BY opt.store_id
),
colors_config AS (
    SELECT
        opt.store_id,
        MIN(opt.created_at) AS first_colors_date,
        MAX(opt.created_at) AS last_colors_date
    FROM {{ source('stg_moltres', 'mwp_options') }} opt
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON s.store_id = opt.store_id
        AND s.created_at > '2024-01-01'
    WHERE (
            opt.option_name LIKE '%compiled_css/style-colors.scss%'
            OR opt.option_name LIKE '%compiled_css/main-color.scss%'
            OR opt.option_name LIKE '%compiled_custom.scss%'
            OR opt.option_name LIKE '%compiled_css/custom-styles.scss%'
        )
        AND opt.option_name LIKE 'ls_theme_pvt_setting%'
    GROUP BY opt.store_id
),
layout_theme AS (
    SELECT
        opt.store_id,
        opt.option_value AS layout_name,
        ROW_NUMBER() OVER (PARTITION BY opt.store_id ORDER BY opt.created_at DESC) AS rn
    FROM {{ source('stg_moltres', 'mwp_options') }} opt
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON s.store_id = opt.store_id
        AND s.created_at > '2024-01-01'
    WHERE opt.option_name = 'twig_template'
)

SELECT
    s.store_id,
    -- Layout configurado = tiene banner + slider + colors
    MAX(CASE
        WHEN bc.store_id IS NOT NULL 
            AND sc.store_id IS NOT NULL 
            AND cc.store_id IS NOT NULL 
        THEN 1
        ELSE 0
    END) AS config_layout,
    -- Nombre del tema/layout actual
    MAX(CASE WHEN lt.rn = 1 THEN lt.layout_name END) AS layout_name,
    -- Primera fecha de config = la más temprana de las 3
    MIN(LEAST(
        COALESCE(bc.first_banner_date, CAST('9999-12-31' AS TIMESTAMP)),
        COALESCE(sc.first_slider_date, CAST('9999-12-31' AS TIMESTAMP)),
        COALESCE(cc.first_colors_date, CAST('9999-12-31' AS TIMESTAMP))
    )) AS first_date_config_layout,
    -- Última fecha de config = la más tardía de las 3 (fecha de completitud)
    MAX(GREATEST(
        COALESCE(bc.last_banner_date, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(sc.last_slider_date, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(cc.last_colors_date, CAST('1900-01-01' AS TIMESTAMP))
    )) AS last_date_config_layout,
    
    -- Auditoría
    MAX(COALESCE(ed.sys_audit_created_on, current_timestamp)) AS sys_audit_created_on,
    MAX(COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products')) AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN banner_config bc ON s.store_id = bc.store_id
LEFT JOIN slider_config sc ON s.store_id = sc.store_id
LEFT JOIN colors_config cc ON s.store_id = cc.store_id
LEFT JOIN layout_theme lt ON s.store_id = lt.store_id AND lt.rn = 1
LEFT JOIN existing_data ed ON s.store_id = ed.store_id
WHERE s.created_at > '2024-01-01'
{% if is_incremental() %}
    AND s.store_id NOT IN (SELECT store_id FROM {{ this }})
{% endif %}
GROUP BY s.store_id

