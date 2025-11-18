{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
    )
}}

-- depends_on:
--   - {{ ref('_int_marketing__onboarding_plan_movements') }}
--   - {{ ref('_int_marketing__onboarding_orders_gmv') }}
--   - {{ ref('company_metrics_paid_orders') }}
--   - {{ ref('moltres__contracts') }}
--   - {{ ref('s__attributes__store_core__ref') }}
--   - {{ ref('s__general__grouping_plans__ref') }}

/*
Data Product: Onboarding 4 Steps Consolidated (GOLD AGG)
Description: Modelo consolidado con todas las métricas de onboarding y 4 steps por tienda
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Business Use: Dashboard consolidado de onboarding con todas las métricas de 4 steps, accesos, sesiones, órdenes, planes, etc.

Spec: 
- Consolida información de múltiples data products: admin access, storefront sessions, layout, products, payments, shipping
- Incluye métricas de órdenes/GMV desde data_operations
- Incluye información de tienda desde data_operations
- Incluye lógica de upgrade/downgrade de planes
- Incluye attribution, tags de onboarding, QLs
- Una fila por store_id

✅ Materialización INCREMENTAL OPTIMIZADA CON COMPARACIÓN DE VALORES:
   - Estrategia MERGE con unique_key=store_id
   - Filtrado inteligente en 2 niveles:
     1. Filtro inicial: Solo procesa tiendas que realmente cambiaron:
        * Tiendas nuevas (no existen en la tabla)
        * Tiendas dentro de ventanas activas (≤ 91 días desde creación para asegurar cálculo completo del día 90)
        * Tiendas con cambios detectados en fuentes upstream (timestamps)
     2. Comparación de valores: Usa hash MD5 de todas las columnas de negocio para:
        * Evitar UPDATEs innecesarios cuando los valores calculados no cambiaron
        * Solo hacer MERGE de tiendas donde el hash cambió o son nuevas
   - Optimizaciones de performance:
     * Uso de LEFT JOIN en lugar de NOT IN / IN para mejor eficiencia
     * Cálculo de hash solo para tiendas que pasaron el filtro inicial
   - Máxima eficiencia: Evita procesar y actualizar tiendas sin cambios reales

⚠️ NOTAS:
   - Este modelo consume de múltiples data products existentes
   - Algunas secciones pueden requerir ajustes según disponibilidad de datos
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
{% if is_incremental() %}
-- Obtener el último timestamp de actualización una sola vez para todas las comparaciones
last_update_time AS (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS max_updated_on
    FROM {{ this }}
),
-- Identificar tiendas con cambios en fuentes upstream
stores_with_changes AS (
    SELECT DISTINCT store_id
    FROM (
        -- Cambios en store_core
        SELECT store_id FROM {{ ref('s__attributes__store_core__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en store_identity
        SELECT store_id FROM {{ ref('s__attributes__store_identity__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en admin access
        SELECT store_id FROM {{ ref('g__product_marketing__admin_access_store__agg') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en storefront sessions
        SELECT store_id FROM {{ ref('g__product_marketing__storefront_sessions_store__agg') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en layout
        SELECT store_id FROM {{ ref('s__product_marketing__layout__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en products
        SELECT store_id FROM {{ ref('s__product_marketing__products__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en payments
        SELECT store_id FROM {{ ref('s__product_marketing__payments__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en shipping
        SELECT store_id FROM {{ ref('s__product_marketing__shipping__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Nuevas órdenes (para actualizar métricas de órdenes/GMV)
        SELECT DISTINCT store_id 
        FROM {{ ref('company_metrics_paid_orders') }}
        WHERE completed_at > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en contratos (para actualizar plan movements)
        SELECT DISTINCT store_id 
        FROM {{ ref('moltres__contracts') }}
        WHERE created_at > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en lifecycle status (para blocked_fraud, active_merchant, etc.)
        SELECT store_id FROM {{ ref('s__lifecycle__store_status__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en attribution
        SELECT store_id FROM {{ ref('s__attributes__acquisition_profile__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en QLs
        SELECT store_id FROM {{ ref('marketing__models__quality_leads__ref') }}
        WHERE created_at > (SELECT max_updated_on FROM last_update_time)
        
        UNION DISTINCT
        
        -- Cambios en tags de onboarding
        -- Nota: usar sys_audit_updated_on si existe, sino usar created como proxy
        SELECT DISTINCT CAST(related_id AS BIGINT) AS store_id
        FROM {{ source('int_moltres', 'mwp_tags') }}
        WHERE tag IN ('new-admin-onboarding-202411-a', 'new-admin-onboarding-202411-b')
        AND COALESCE(
            CAST(sys_audit_updated_on AS TIMESTAMP),
            CAST(created AS TIMESTAMP)
        ) > (SELECT max_updated_on FROM last_update_time)
    )
),
{% endif %}

-- ============================================
-- ADMIN ACCESS: Métricas de accesos al admin
-- ============================================
admin_access AS (
    SELECT 
        store_id,
        qty_admin_access_7d,
        qty_admin_access_15d,
        qty_admin_access_30d,
        qty_admin_access_60d,
        first_date_admin_access,
        last_date_admin_access
    FROM {{ ref('g__product_marketing__admin_access_store__agg') }}
),

-- ============================================
-- STOREFRONT SESSIONS: Métricas de sesiones de usuarios finales
-- ============================================
storefront_sessions AS (
    SELECT 
        store_id,
        first_store_session,
        store_sessions_7d,
        store_sessions_15d,
        store_sessions_30d,
        store_sessions_60d,
        store_sessions_90d,
        last_store_session
    FROM {{ ref('g__product_marketing__storefront_sessions_store__agg') }}
),

-- ============================================
-- LAYOUT: Configuración de layout/tema
-- ============================================
layout AS (
    SELECT 
        store_id,
        config_layout,
        layout_name,
        config_banner,
        config_slider,
        config_colors,
        first_date_config_layout,
        last_date_config_layout
    FROM {{ ref('s__product_marketing__layout__ref') }}
),

-- ============================================
-- PRODUCTS: Configuración de productos (4 steps)
-- ============================================
products AS (
    SELECT 
        store_id,
        config_products,
        first_date_config_products,
        last_date_config_products
    FROM {{ ref('s__product_marketing__products__ref') }}
),

-- ============================================
-- PAYMENTS: Configuración de métodos de pago (4 steps)
-- ============================================
payments AS (
    SELECT 
        store_id,
        config_payment,
        first_date_config_payment,
        last_date_config_payment
    FROM {{ ref('s__product_marketing__payments__ref') }}
),

-- ============================================
-- SHIPPING: Configuración de métodos de envío (4 steps)
-- ============================================
shipping AS (
    SELECT 
        store_id,
        config_shipping,
        first_date_config_shipping,
        last_date_config_shipping
    FROM {{ ref('s__product_marketing__shipping__ref') }}
),

-- ============================================
-- STORE INFO & CONTACT: Información básica de tienda y contacto
-- ============================================
store_info AS (
    SELECT 
        si.store_id,
        si.store_name,
        sc.country_code AS country,
        sc.created_at,
        ls.first_payment,
        ls.first_seller_at,
        ls.current_segment,
        ls.current_plan_name AS current_plan,
        sc.vertical_name AS vertical,
        si.main_user_id,
        si.user_email,
        si.owner_phone_number,
        si.phone_from_footer,
        si.phone_whatsapp_button AS whatsapp_button
    FROM {{ ref('s__attributes__store_identity__ref') }} si
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} sc
        ON si.store_id = sc.store_id
    LEFT JOIN {{ ref('s__lifecycle__store_status__ref') }} ls
        ON si.store_id = ls.store_id
),

-- ============================================
-- ORDERS & GMV: Métricas de órdenes y GMV
-- Consumido desde modelo intermedio
-- ============================================
orders_gmv AS (
    SELECT *
    FROM {{ ref('_int_marketing__onboarding_orders_gmv') }}
),

-- ============================================
-- BLOCKED FRAUD TAG: Tag de bloqueo por fraude
-- Obtener is_store_blocked desde s__lifecycle__store_status__ref (viene de moltres__mwp_store_info)
-- Este campo está disponible en storefronts_curated__sessions según Bárbara
-- ============================================
blocked_fraud AS (
    SELECT 
        store_id,
        CASE WHEN is_store_blocked = TRUE THEN 1 ELSE 0 END AS blocked_fraud_tag
    FROM {{ ref('s__lifecycle__store_status__ref') }}
),

-- ============================================
-- ATTRIBUTION: Información de atribución de marketing
-- Consumido desde s__attributes__acquisition_profile__ref (domain merchant)
-- ============================================
attribution AS (
    SELECT 
        att.store_id,
        att.mkt_source_first_click,
        att.mkt_subteam_first_click,
        att.mkt_source_last_click,
        att.mkt_subteam_last_click,
        -- active_merchant_probability: Usamos is_active_merchant de s__lifecycle__store_status__ref como probabilidad (0 o 1)
        -- Si necesitas una probabilidad real (0-1), habría que usar un modelo de ML específico
        COALESCE(ls.is_active_merchant, 0) AS active_merchant_probability
    FROM {{ ref('s__attributes__acquisition_profile__ref') }} att
    LEFT JOIN {{ ref('s__lifecycle__store_status__ref') }} ls
        ON att.store_id = ls.store_id
),

-- ============================================
-- ONBOARDING TAGS: Tags de nuevo onboarding
-- Consumido desde int_moltres.mwp_tags
-- ============================================
onboarding_tags AS (
    SELECT 
        CAST(related_id AS BIGINT) AS store_id,
        tag AS onboarding_tag
    FROM {{ source('int_moltres', 'mwp_tags') }}
    WHERE tag IN ('new-admin-onboarding-202411-a', 'new-admin-onboarding-202411-b')
),

-- ============================================
-- PLAN MOVEMENTS: Upgrade/downgrade de planes
-- Consumido desde modelo intermedio
-- ============================================
plan_movements AS (
    SELECT *
    FROM {{ ref('_int_marketing__onboarding_plan_movements') }}
),

-- ============================================
-- QLs: Modelos de predicción de pago
-- Consumido desde marketing__models__quality_leads__ref y marketing_cutoffs_table
-- ============================================
ql_models AS (
    SELECT 
        sc.store_id,
        ql.predicted_prob AS new_payment_probability,
        cutoff.cutoff AS cutoff_ql
    FROM {{ ref('s__attributes__store_core__ref') }} sc
    LEFT JOIN {{ ref('marketing__models__quality_leads__ref') }} ql
        ON sc.store_id = ql.store_id
    LEFT JOIN {{ source('int_data_predictors', 'marketing_cutoffs_table') }} cutoff
        ON sc.country_code = cutoff.country
        AND ql.model_id = cutoff.model_id
        AND (cutoff.device = sc.device OR cutoff.device IS NULL)
    WHERE sc.created_at >= '2024-01-01'
),

-- ============================================
-- SELECT FINAL: Consolidación de todas las fuentes
-- ============================================
final_data AS (
    SELECT 
        -- Store ID (PK)
        si.store_id,
        
        -- ============================================
        -- INFO Y CONTACTO
        -- ============================================
        si.store_name,
        si.country,
        si.created_at,
        si.first_payment,
        si.first_seller_at,
        si.current_segment,
        si.current_plan,
        si.vertical,
        si.main_user_id,
        si.user_email,
        si.owner_phone_number,
        si.phone_from_footer,
        si.whatsapp_button,
        
        -- ============================================
        -- ADMIN ACCESS
        -- ============================================
        COALESCE(aa.qty_admin_access_7d, 0) AS qty_admin_access_7d,
        COALESCE(aa.qty_admin_access_15d, 0) AS qty_admin_access_15d,
        COALESCE(aa.qty_admin_access_30d, 0) AS qty_admin_access_30d,
        COALESCE(aa.qty_admin_access_60d, 0) AS qty_admin_access_60d,
        aa.first_date_admin_access,
        aa.last_date_admin_access,
        
        -- ============================================
        -- STOREFRONT SESSIONS
        -- ============================================
        ss.first_store_session,
        COALESCE(ss.store_sessions_7d, 0) AS qty_sessions_7d,
        COALESCE(ss.store_sessions_15d, 0) AS qty_sessions_15d,
        COALESCE(ss.store_sessions_30d, 0) AS qty_sessions_30d,
        COALESCE(ss.store_sessions_60d, 0) AS qty_sessions_60d,
        COALESCE(ss.store_sessions_90d, 0) AS qty_sessions_90d,
        ss.last_store_session,
        
        -- ============================================
        -- LAYOUT
        -- ============================================
        COALESCE(l.config_layout, 0) AS config_layout,
        l.layout_name,
        COALESCE(l.config_banner, 0) AS theme_banner,
        COALESCE(l.config_slider, 0) AS theme_slider,
        COALESCE(l.config_colors, 0) AS theme_color_change,
        l.first_date_config_layout,
        l.last_date_config_layout,
        
        -- ============================================
        -- 4 STEPS - PRODUCTS
        -- ============================================
        COALESCE(p.config_products, 0) AS config_products,
        p.first_date_config_products,
        p.last_date_config_products,
        
        -- ============================================
        -- 4 STEPS - PAYMENTS
        -- ============================================
        COALESCE(pay.config_payment, 0) AS config_payment,
        pay.first_date_config_payment,
        pay.last_date_config_payment,
        
        -- ============================================
        -- 4 STEPS - SHIPPING
        -- ============================================
        COALESCE(sh.config_shipping, 0) AS config_shipping,
        sh.first_date_config_shipping,
        sh.last_date_config_shipping,
        
        -- ============================================
        -- ORDERS & GMV
        -- ============================================
        og.first_order,
        og.time_to_first_order,
        og.orders_7,
        og.orders_15,
        og.orders_30,
        og.orders_60,
        og.orders_90,
        og.gmv_30,
        og.gmv_60,
        og.gmv_90,
        og.gmv_dol_30,
        og.gmv_dol_60,
        og.gmv_dol_90,
        
        -- ============================================
        -- PLAN MOVEMENTS
        -- ============================================
        pm.upgrade_d7,
        pm.upgrade_d15,
        pm.upgrade_d30,
        pm.downgrade_d7,
        pm.downgrade_d15,
        pm.downgrade_d30,
        pm.primeiro_plano,
        pm.max_plan_d7,
        pm.max_plan_d15,
        pm.max_plan_d30,
        
        -- ============================================
        -- ATTRIBUTION
        -- ============================================
        att.mkt_source_first_click,
        att.mkt_subteam_first_click,
        att.mkt_source_last_click,
        att.mkt_subteam_last_click,
        att.active_merchant_probability,
        
        -- ============================================
        -- ONBOARDING TAGS
        -- ============================================
        ot.onboarding_tag,
        
        -- ============================================
        -- QLs
        -- ============================================
        ql.new_payment_probability,
        ql.cutoff_ql,
        
        -- ============================================
        -- BLOCKED FRAUD TAG
        -- ============================================
        COALESCE(bf.blocked_fraud_tag, 0) AS blocked_fraud_tag,
        
        -- ============================================
        -- HASH para detectar cambios en valores
        -- ============================================
        MD5(
            CONCAT_WS('||',
                CAST(si.store_id AS STRING),
                COALESCE(si.store_name, ''),
                COALESCE(si.country, ''),
                COALESCE(CAST(si.created_at AS STRING), ''),
                COALESCE(CAST(si.first_payment AS STRING), ''),
                COALESCE(CAST(si.first_seller_at AS STRING), ''),
                COALESCE(si.current_segment, ''),
                COALESCE(si.current_plan, ''),
                COALESCE(si.vertical, ''),
                COALESCE(CAST(si.main_user_id AS STRING), ''),
                COALESCE(si.user_email, ''),
                COALESCE(si.owner_phone_number, ''),
                COALESCE(si.phone_from_footer, ''),
                COALESCE(si.whatsapp_button, ''),
                COALESCE(CAST(COALESCE(aa.qty_admin_access_7d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(aa.qty_admin_access_15d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(aa.qty_admin_access_30d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(aa.qty_admin_access_60d, 0) AS STRING), ''),
                COALESCE(CAST(aa.first_date_admin_access AS STRING), ''),
                COALESCE(CAST(aa.last_date_admin_access AS STRING), ''),
                COALESCE(CAST(ss.first_store_session AS STRING), ''),
                COALESCE(CAST(COALESCE(ss.store_sessions_7d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(ss.store_sessions_15d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(ss.store_sessions_30d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(ss.store_sessions_60d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(ss.store_sessions_90d, 0) AS STRING), ''),
                COALESCE(CAST(ss.last_store_session AS STRING), ''),
                COALESCE(CAST(COALESCE(l.config_layout, 0) AS STRING), ''),
                COALESCE(l.layout_name, ''),
                COALESCE(CAST(COALESCE(l.config_banner, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(l.config_slider, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(l.config_colors, 0) AS STRING), ''),
                COALESCE(CAST(l.first_date_config_layout AS STRING), ''),
                COALESCE(CAST(l.last_date_config_layout AS STRING), ''),
                COALESCE(CAST(COALESCE(p.config_products, 0) AS STRING), ''),
                COALESCE(CAST(p.first_date_config_products AS STRING), ''),
                COALESCE(CAST(p.last_date_config_products AS STRING), ''),
                COALESCE(CAST(COALESCE(pay.config_payment, 0) AS STRING), ''),
                COALESCE(CAST(pay.first_date_config_payment AS STRING), ''),
                COALESCE(CAST(pay.last_date_config_payment AS STRING), ''),
                COALESCE(CAST(COALESCE(sh.config_shipping, 0) AS STRING), ''),
                COALESCE(CAST(sh.first_date_config_shipping AS STRING), ''),
                COALESCE(CAST(sh.last_date_config_shipping AS STRING), ''),
                COALESCE(CAST(og.first_order AS STRING), ''),
                COALESCE(CAST(og.time_to_first_order AS STRING), ''),
                COALESCE(CAST(og.orders_7 AS STRING), ''),
                COALESCE(CAST(og.orders_15 AS STRING), ''),
                COALESCE(CAST(og.orders_30 AS STRING), ''),
                COALESCE(CAST(og.orders_60 AS STRING), ''),
                COALESCE(CAST(og.orders_90 AS STRING), ''),
                COALESCE(CAST(og.gmv_30 AS STRING), ''),
                COALESCE(CAST(og.gmv_60 AS STRING), ''),
                COALESCE(CAST(og.gmv_90 AS STRING), ''),
                COALESCE(CAST(og.gmv_dol_30 AS STRING), ''),
                COALESCE(CAST(og.gmv_dol_60 AS STRING), ''),
                COALESCE(CAST(og.gmv_dol_90 AS STRING), ''),
                COALESCE(CAST(pm.upgrade_d7 AS STRING), ''),
                COALESCE(CAST(pm.upgrade_d15 AS STRING), ''),
                COALESCE(CAST(pm.upgrade_d30 AS STRING), ''),
                COALESCE(CAST(pm.downgrade_d7 AS STRING), ''),
                COALESCE(CAST(pm.downgrade_d15 AS STRING), ''),
                COALESCE(CAST(pm.downgrade_d30 AS STRING), ''),
                COALESCE(CAST(pm.primeiro_plano AS STRING), ''),
                COALESCE(CAST(pm.max_plan_d7 AS STRING), ''),
                COALESCE(CAST(pm.max_plan_d15 AS STRING), ''),
                COALESCE(CAST(pm.max_plan_d30 AS STRING), ''),
                COALESCE(att.mkt_source_first_click, ''),
                COALESCE(att.mkt_subteam_first_click, ''),
                COALESCE(att.mkt_source_last_click, ''),
                COALESCE(att.mkt_subteam_last_click, ''),
                COALESCE(CAST(att.active_merchant_probability AS STRING), ''),
                COALESCE(ot.onboarding_tag, ''),
                COALESCE(CAST(ql.new_payment_probability AS STRING), ''),
                COALESCE(CAST(ql.cutoff_ql AS STRING), ''),
                COALESCE(CAST(COALESCE(bf.blocked_fraud_tag, 0) AS STRING), '')
            )
        ) AS row_hash

    FROM {{ ref('s__attributes__store_core__ref') }} sc
    INNER JOIN store_info si ON sc.store_id = si.store_id
    {% if is_incremental() %}
    -- Optimización: LEFT JOIN para detectar tiendas nuevas y con cambios (más eficiente que NOT IN / IN)
    LEFT JOIN existing_data ed_filter ON sc.store_id = ed_filter.store_id
    LEFT JOIN stores_with_changes swc ON sc.store_id = swc.store_id
    {% endif %}
    LEFT JOIN admin_access aa ON sc.store_id = aa.store_id
    LEFT JOIN storefront_sessions ss ON sc.store_id = ss.store_id
    LEFT JOIN layout l ON sc.store_id = l.store_id
    LEFT JOIN products p ON sc.store_id = p.store_id
    LEFT JOIN payments pay ON sc.store_id = pay.store_id
    LEFT JOIN shipping sh ON sc.store_id = sh.store_id
    LEFT JOIN orders_gmv og ON sc.store_id = og.store_id
    LEFT JOIN plan_movements pm ON sc.store_id = pm.store_id
    LEFT JOIN attribution att ON sc.store_id = att.store_id
    LEFT JOIN onboarding_tags ot ON sc.store_id = ot.store_id
    LEFT JOIN ql_models ql ON sc.store_id = ql.store_id
    LEFT JOIN blocked_fraud bf ON sc.store_id = bf.store_id
    WHERE sc.created_at >= '2024-01-01'
        -- Nota: s__attributes__store_core__ref ya filtra tiendas con state = 4 en su post_hook
    {% if is_incremental() %}
        -- Solo procesar tiendas que realmente cambiaron:
        -- 1. Tiendas nuevas (no existen en la tabla)
        -- 2. Tiendas dentro de ventanas activas (pueden cambiar métricas históricas)
        --    Ventana más larga: 90 días (día 0 al día 90 inclusive = 91 días totales)
        -- 3. Tiendas con cambios detectados en fuentes upstream (timestamps)
        AND (
            -- Tiendas nuevas (optimizado: LEFT JOIN + IS NULL es más eficiente que NOT IN)
            ed_filter.store_id IS NULL
            -- O tiendas dentro de ventanas activas (hasta día 91 para asegurar cálculo completo del día 90)
            OR DATEDIFF(DAY, sc.created_at, CURRENT_DATE) <= 91
            -- O tiendas con cambios detectados en fuentes upstream (optimizado: LEFT JOIN + IS NOT NULL es más eficiente que IN)
            OR swc.store_id IS NOT NULL
        )
    {% endif %}
),
{% if is_incremental() %}
-- Comparar hash con datos existentes para evitar UPDATEs innecesarios
-- Optimización: Solo calcular hash para tiendas que pasaron el filtro inicial (no todas las tiendas de la tabla)
-- Usamos el mismo criterio de filtrado que en final_data para reducir el cálculo de hash
stores_to_check_hash AS (
    SELECT DISTINCT sc.store_id
    FROM {{ ref('s__attributes__store_core__ref') }} sc
    LEFT JOIN existing_data ed_filter_hash ON sc.store_id = ed_filter_hash.store_id
    LEFT JOIN stores_with_changes swc_filter_hash ON sc.store_id = swc_filter_hash.store_id
    WHERE sc.created_at >= '2024-01-01'
    AND (
        -- Tiendas nuevas (optimizado: LEFT JOIN + IS NULL es más eficiente que NOT IN)
        ed_filter_hash.store_id IS NULL
        -- O tiendas dentro de ventanas activas
        OR DATEDIFF(DAY, sc.created_at, CURRENT_DATE) <= 91
        -- O tiendas con cambios detectados en fuentes upstream (optimizado: LEFT JOIN + IS NOT NULL es más eficiente que IN)
        OR swc_filter_hash.store_id IS NOT NULL
    )
),
existing_with_hash AS (
    SELECT 
        t.store_id,
        MD5(
            CONCAT_WS('||',
                CAST(t.store_id AS STRING),
                COALESCE(t.store_name, ''),
                COALESCE(t.country, ''),
                COALESCE(CAST(t.created_at AS STRING), ''),
                COALESCE(CAST(t.first_payment AS STRING), ''),
                COALESCE(CAST(t.first_seller_at AS STRING), ''),
                COALESCE(t.current_segment, ''),
                COALESCE(t.current_plan, ''),
                COALESCE(t.vertical, ''),
                COALESCE(CAST(t.main_user_id AS STRING), ''),
                COALESCE(t.user_email, ''),
                COALESCE(t.owner_phone_number, ''),
                COALESCE(t.phone_from_footer, ''),
                COALESCE(t.whatsapp_button, ''),
                COALESCE(CAST(COALESCE(t.qty_admin_access_7d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.qty_admin_access_15d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.qty_admin_access_30d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.qty_admin_access_60d, 0) AS STRING), ''),
                COALESCE(CAST(t.first_date_admin_access AS STRING), ''),
                COALESCE(CAST(t.last_date_admin_access AS STRING), ''),
                COALESCE(CAST(t.first_store_session AS STRING), ''),
                COALESCE(CAST(COALESCE(t.qty_sessions_7d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.qty_sessions_15d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.qty_sessions_30d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.qty_sessions_60d, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.qty_sessions_90d, 0) AS STRING), ''),
                COALESCE(CAST(t.last_store_session AS STRING), ''),
                COALESCE(CAST(COALESCE(t.config_layout, 0) AS STRING), ''),
                COALESCE(t.layout_name, ''),
                COALESCE(CAST(COALESCE(t.theme_banner, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.theme_slider, 0) AS STRING), ''),
                COALESCE(CAST(COALESCE(t.theme_color_change, 0) AS STRING), ''),
                COALESCE(CAST(t.first_date_config_layout AS STRING), ''),
                COALESCE(CAST(t.last_date_config_layout AS STRING), ''),
                COALESCE(CAST(COALESCE(t.config_products, 0) AS STRING), ''),
                COALESCE(CAST(t.first_date_config_products AS STRING), ''),
                COALESCE(CAST(t.last_date_config_products AS STRING), ''),
                COALESCE(CAST(COALESCE(t.config_payment, 0) AS STRING), ''),
                COALESCE(CAST(t.first_date_config_payment AS STRING), ''),
                COALESCE(CAST(t.last_date_config_payment AS STRING), ''),
                COALESCE(CAST(COALESCE(t.config_shipping, 0) AS STRING), ''),
                COALESCE(CAST(t.first_date_config_shipping AS STRING), ''),
                COALESCE(CAST(t.last_date_config_shipping AS STRING), ''),
                COALESCE(CAST(t.first_order AS STRING), ''),
                COALESCE(CAST(t.time_to_first_order AS STRING), ''),
                COALESCE(CAST(t.orders_7 AS STRING), ''),
                COALESCE(CAST(t.orders_15 AS STRING), ''),
                COALESCE(CAST(t.orders_30 AS STRING), ''),
                COALESCE(CAST(t.orders_60 AS STRING), ''),
                COALESCE(CAST(t.orders_90 AS STRING), ''),
                COALESCE(CAST(t.gmv_30 AS STRING), ''),
                COALESCE(CAST(t.gmv_60 AS STRING), ''),
                COALESCE(CAST(t.gmv_90 AS STRING), ''),
                COALESCE(CAST(t.gmv_dol_30 AS STRING), ''),
                COALESCE(CAST(t.gmv_dol_60 AS STRING), ''),
                COALESCE(CAST(t.gmv_dol_90 AS STRING), ''),
                COALESCE(CAST(t.upgrade_d7 AS STRING), ''),
                COALESCE(CAST(t.upgrade_d15 AS STRING), ''),
                COALESCE(CAST(t.upgrade_d30 AS STRING), ''),
                COALESCE(CAST(t.downgrade_d7 AS STRING), ''),
                COALESCE(CAST(t.downgrade_d15 AS STRING), ''),
                COALESCE(CAST(t.downgrade_d30 AS STRING), ''),
                COALESCE(CAST(t.primeiro_plano AS STRING), ''),
                COALESCE(CAST(t.max_plan_d7 AS STRING), ''),
                COALESCE(CAST(t.max_plan_d15 AS STRING), ''),
                COALESCE(CAST(t.max_plan_d30 AS STRING), ''),
                COALESCE(t.mkt_source_first_click, ''),
                COALESCE(t.mkt_subteam_first_click, ''),
                COALESCE(t.mkt_source_last_click, ''),
                COALESCE(t.mkt_subteam_last_click, ''),
                COALESCE(CAST(t.active_merchant_probability AS STRING), ''),
                COALESCE(t.onboarding_tag, ''),
                COALESCE(CAST(t.new_payment_probability AS STRING), ''),
                COALESCE(CAST(t.cutoff_ql AS STRING), ''),
                COALESCE(CAST(COALESCE(t.blocked_fraud_tag, 0) AS STRING), '')
            )
        ) AS existing_hash
    FROM {{ this }} t
    -- Optimización: Solo calcular hash para tiendas que pasaron el filtro inicial
    INNER JOIN stores_to_check_hash stch ON t.store_id = stch.store_id
),
{% endif %}
-- Solo incluir filas que cambiaron o son nuevas
final_filtered AS (
    SELECT 
        fd.*,
        COALESCE(ed.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
        COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM final_data fd
    LEFT JOIN existing_data ed ON fd.store_id = ed.store_id
    {% if is_incremental() %}
    LEFT JOIN existing_with_hash ewh ON fd.store_id = ewh.store_id
    WHERE 
        -- Incluir tiendas nuevas (no existen en la tabla)
        ed.store_id IS NULL
        -- O tiendas donde el hash cambió (valores realmente diferentes)
        -- Usar IS DISTINCT FROM para manejar NULLs correctamente
        OR (fd.row_hash IS DISTINCT FROM ewh.existing_hash)
    {% endif %}
)

SELECT 
    store_id,
    store_name,
    country,
    created_at,
    first_payment,
    first_seller_at,
    current_segment,
    current_plan,
    vertical,
    main_user_id,
    user_email,
    owner_phone_number,
    phone_from_footer,
    whatsapp_button,
    qty_admin_access_7d,
    qty_admin_access_15d,
    qty_admin_access_30d,
    qty_admin_access_60d,
    first_date_admin_access,
    last_date_admin_access,
    first_store_session,
    qty_sessions_7d,
    qty_sessions_15d,
    qty_sessions_30d,
    qty_sessions_60d,
    qty_sessions_90d,
    last_store_session,
    config_layout,
    layout_name,
    theme_banner,
    theme_slider,
    theme_color_change,
    first_date_config_layout,
    last_date_config_layout,
    config_products,
    first_date_config_products,
    last_date_config_products,
    config_payment,
    first_date_config_payment,
    last_date_config_payment,
    config_shipping,
    first_date_config_shipping,
    last_date_config_shipping,
    first_order,
    time_to_first_order,
    orders_7,
    orders_15,
    orders_30,
    orders_60,
    orders_90,
    gmv_30,
    gmv_60,
    gmv_90,
    gmv_dol_30,
    gmv_dol_60,
    gmv_dol_90,
    upgrade_d7,
    upgrade_d15,
    upgrade_d30,
    downgrade_d7,
    downgrade_d15,
    downgrade_d30,
    primeiro_plano,
    max_plan_d7,
    max_plan_d15,
    max_plan_d30,
    mkt_source_first_click,
    mkt_subteam_first_click,
    mkt_source_last_click,
    mkt_subteam_last_click,
    active_merchant_probability,
    onboarding_tag,
    new_payment_probability,
    cutoff_ql,
    blocked_fraud_tag,
    sys_audit_created_on,
    sys_audit_created_by,
    sys_audit_updated_on,
    sys_audit_updated_by
FROM final_filtered

