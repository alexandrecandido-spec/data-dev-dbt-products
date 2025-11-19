{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
    )
}}

-- depends_on:
--   - {{ ref('_int_marketing__onboarding_orders_gmv') }}
--   - {{ ref('s__attributes__store_core__ref') }}
--   - {{ ref('s__attributes__store_identity__ref') }}
--   - {{ ref('g__product_marketing__admin_access_store__agg') }}
--   - {{ ref('g__product_marketing__storefront_sessions_store__agg') }}
--   - {{ ref('s__product_marketing__layout__ref') }}
--   - {{ ref('s__product_marketing__products__ref') }}
--   - {{ ref('s__product_marketing__payments__ref') }}
--   - {{ ref('s__product_marketing__shipping__ref') }}
--   - {{ ref('s__lifecycle__store_status__ref') }}
--   - {{ ref('s__attributes__acquisition_profile__ref') }}
--   - {{ ref('marketing__models__quality_leads__ref') }}
--   - {{ ref('company_metrics_paid_orders') }}
--   - {{ ref('s__contracts__store_contracts__scd') }}
--   - {{ source('int_moltres', 'mwp_tags') }}
--   - {{ source('int_data_predictors', 'marketing_cutoffs_table') }}

/*
Data Product: Onboarding 4 Steps Consolidated (GOLD AGG)
Description: Modelo consolidado con todas las métricas de onboarding y 4 steps por tienda
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Business Use: Dashboard consolidado de onboarding con todas las métricas de 4 steps, accesos, sesiones, órdenes, planes, etc.

Spec: 
- Consolida información de múltiples data products: admin access, storefront sessions, layout, products, payments, shipping
- Incluye métricas de órdenes/GMV desde _int_marketing__onboarding_orders_gmv (modelo intermedio ephemeral)
- Incluye información de tienda desde data_operations
- Incluye lógica de upgrade/downgrade de planes calculada directamente desde s__contracts__store_contracts__scd (SILVER)
- Incluye attribution desde s__attributes__acquisition_profile__ref (domain merchant), tags de onboarding (int_moltres.mwp_tags), QLs
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
   - Máxima eficiencia: Evita procesar y actualizar tiendas sin cambios reales

⚠️ NOTAS:
   - Este modelo consume de múltiples data products existentes
   - Algunas secciones pueden requerir ajustes según disponibilidad de datos
   - Tags de onboarding se consumen desde int_moltres.mwp_tags (intermediate source) siguiendo arquitectura raw → staging → intermediate → silver → gold
*/

-- El modelo ephemeral _int_marketing__onboarding_orders_gmv se compila primero automáticamente por dbt
-- Luego viene el WITH principal del modelo
-- Optimización: Usamos directamente s__attributes__store_core__ref en lugar de un CTE
-- device_calculated se calcula solo donde se necesita (JOIN con cutoff)

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
        
        UNION ALL
        
        -- Cambios en store_identity
        SELECT store_id FROM {{ ref('s__attributes__store_identity__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en admin access
        SELECT store_id FROM {{ ref('g__product_marketing__admin_access_store__agg') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en storefront sessions
        SELECT store_id FROM {{ ref('g__product_marketing__storefront_sessions_store__agg') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en layout
        SELECT store_id FROM {{ ref('s__product_marketing__layout__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en products
        SELECT store_id FROM {{ ref('s__product_marketing__products__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en payments
        SELECT store_id FROM {{ ref('s__product_marketing__payments__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en shipping
        SELECT store_id FROM {{ ref('s__product_marketing__shipping__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Nuevas órdenes (para actualizar métricas de órdenes/GMV)
        SELECT DISTINCT store_id 
        FROM {{ ref('company_metrics_paid_orders') }}
        WHERE completed_at > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en contratos (para actualizar plan movements)
        SELECT DISTINCT store_id 
        FROM {{ ref('s__contracts__store_contracts__scd') }}
        WHERE created_at_contract > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en lifecycle status (para blocked_fraud, active_merchant, etc.)
        SELECT store_id FROM {{ ref('s__lifecycle__store_status__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en attribution
        SELECT store_id FROM {{ ref('s__attributes__acquisition_profile__ref') }}
        WHERE sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en QLs
        SELECT store_id FROM {{ ref('marketing__models__quality_leads__ref') }}
        WHERE created_at > (SELECT max_updated_on FROM last_update_time)
        
        UNION ALL
        
        -- Cambios en tags de onboarding
        -- Optimización: Evitar COALESCE innecesario - evaluar condiciones explícitamente
        SELECT DISTINCT CAST(related_id AS BIGINT) AS store_id
        FROM {{ source('int_moltres', 'mwp_tags') }}
        WHERE tag IN ('new-admin-onboarding-202411-a', 'new-admin-onboarding-202411-b')
        AND (
            sys_audit_updated_on > (SELECT max_updated_on FROM last_update_time)
            OR (sys_audit_updated_on IS NULL AND created > (SELECT max_updated_on FROM last_update_time))
        )
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
-- Optimización: JOINs movidos directamente a final_data para evitar CTE redundante
-- ============================================

-- ============================================
-- ORDERS & GMV: Métricas de órdenes y GMV
-- Usa modelo intermedio _int_marketing__onboarding_orders_gmv
-- ============================================
orders_gmv AS (
    SELECT * FROM {{ ref('_int_marketing__onboarding_orders_gmv') }}
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
-- Calculado desde s__contracts__store_contracts__scd (SILVER) comparando group_order_id de planes
-- ============================================
contracts_with_plan_info AS (
    SELECT 
        c.store_id,
        c.plan_name,
        c.created_at_contract AS created_at,
        c.start_date,
        c.plan_name AS plan_group,
        -- Optimización: Calcular DATEDIFF una vez para evitar recálculos en CTEs siguientes
        DATEDIFF(DAY, s.created_at, DATE(c.created_at_contract)) AS days_from_creation,
        CASE 
            WHEN c.plan_name IN ('test_broken','no-stores') THEN 0
            WHEN c.plan_name IN ('zero-fee','freemium') THEN 1
            WHEN c.plan_name IN ('lojinha','plan-a','plan-emprendedor') THEN 2
            WHEN c.plan_name IN ('plan-b') THEN 3
            WHEN c.plan_name IN ('plan-c') THEN 4
            WHEN c.plan_name IN ('enterprise') THEN 5
            ELSE -1 
        END AS plan_order_id,
        s.created_at AS store_created_at
    FROM {{ ref('s__contracts__store_contracts__scd') }} c
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON c.store_id = s.store_id
        AND s.created_at >= '{{ var("onboarding_start_date") }}'
    WHERE c.plan_name IS NOT NULL
),

first_plan AS (
    SELECT 
        store_id,
        plan_group AS primeiro_plano,
        plan_order_id AS first_plan_order_id
    FROM (
        SELECT 
            store_id,
            plan_group,
            plan_order_id,
            ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY created_at ASC, start_date ASC) AS rn
        FROM contracts_with_plan_info
    ) ranked
    WHERE rn = 1
),

max_plan_by_window AS (
    SELECT 
        store_id,
        -- Optimización: Usar days_from_creation calculado una vez en lugar de recalcular DATEDIFF
        MAX(CASE WHEN days_from_creation <= 7 THEN plan_order_id ELSE -1 END) AS max_plan_order_d7,
        MAX(CASE WHEN days_from_creation <= 15 THEN plan_order_id ELSE -1 END) AS max_plan_order_d15,
        MAX(CASE WHEN days_from_creation <= 30 THEN plan_order_id ELSE -1 END) AS max_plan_order_d30,
        MAX(CASE WHEN days_from_creation <= 7 THEN plan_group ELSE NULL END) AS max_plan_d7,
        MAX(CASE WHEN days_from_creation <= 15 THEN plan_group ELSE NULL END) AS max_plan_d15,
        MAX(CASE WHEN days_from_creation <= 30 THEN plan_group ELSE NULL END) AS max_plan_d30
    FROM contracts_with_plan_info
    GROUP BY store_id
),

-- Plan al final de cada ventana (último plan activo dentro de la ventana)
-- Usamos ROW_NUMBER para obtener el último contrato dentro de cada ventana
contracts_ranked_by_window AS (
    SELECT 
        c.store_id,
        c.plan_order_id,
        c.days_from_creation,
        ROW_NUMBER() OVER (
            PARTITION BY c.store_id, 
                CASE 
                    WHEN c.days_from_creation <= 7 THEN 7
                    WHEN c.days_from_creation <= 15 THEN 15
                    WHEN c.days_from_creation <= 30 THEN 30
                    ELSE NULL
                END
            ORDER BY c.created_at DESC, c.start_date DESC
        ) AS rn
    FROM contracts_with_plan_info c
    WHERE c.days_from_creation <= 30
),

plan_at_end_of_window AS (
    SELECT 
        store_id,
        MAX(CASE WHEN days_from_creation <= 7 AND rn = 1 THEN plan_order_id ELSE -1 END) AS plan_order_d7,
        MAX(CASE WHEN days_from_creation <= 15 AND rn = 1 THEN plan_order_id ELSE -1 END) AS plan_order_d15,
        MAX(CASE WHEN days_from_creation <= 30 AND rn = 1 THEN plan_order_id ELSE -1 END) AS plan_order_d30
    FROM contracts_ranked_by_window
    GROUP BY store_id
),

plan_movements AS (
    SELECT 
        sc.store_id,
        fp.primeiro_plano,
        mp.max_plan_d7,
        mp.max_plan_d15,
        mp.max_plan_d30,
        -- Upgrade: si el plan máximo en la ventana es mayor que el primer plan
        CASE WHEN mp.max_plan_order_d7 > COALESCE(fp.first_plan_order_id, -1) THEN 1 ELSE 0 END AS upgrade_d7,
        CASE WHEN mp.max_plan_order_d15 > COALESCE(fp.first_plan_order_id, -1) THEN 1 ELSE 0 END AS upgrade_d15,
        CASE WHEN mp.max_plan_order_d30 > COALESCE(fp.first_plan_order_id, -1) THEN 1 ELSE 0 END AS upgrade_d30,
        -- Downgrade: si el plan al final de la ventana es menor que el plan máximo alcanzado en esa ventana
        CASE 
            WHEN mp.max_plan_order_d7 > 0 
                AND pe.plan_order_d7 >= 0 
                AND pe.plan_order_d7 < mp.max_plan_order_d7 
            THEN 1 
            ELSE 0 
        END AS downgrade_d7,
        CASE 
            WHEN mp.max_plan_order_d15 > 0 
                AND pe.plan_order_d15 >= 0 
                AND pe.plan_order_d15 < mp.max_plan_order_d15 
            THEN 1 
            ELSE 0 
        END AS downgrade_d15,
        CASE 
            WHEN mp.max_plan_order_d30 > 0 
                AND pe.plan_order_d30 >= 0 
                AND pe.plan_order_d30 < mp.max_plan_order_d30 
            THEN 1 
            ELSE 0 
        END AS downgrade_d30
    FROM {{ ref('s__attributes__store_core__ref') }} sc
    LEFT JOIN first_plan fp ON sc.store_id = fp.store_id
    LEFT JOIN max_plan_by_window mp ON sc.store_id = mp.store_id
    LEFT JOIN plan_at_end_of_window pe ON sc.store_id = pe.store_id
    WHERE sc.created_at >= '{{ var("onboarding_start_date") }}'
),

-- ============================================
-- STORE CORE WITH DEVICE: Calcular device solo donde se necesita
-- Usado solo para el JOIN con cutoff
-- ============================================
store_core_with_device_for_cutoff AS (
    SELECT 
        sc.store_id,
        sc.country_code,
        COALESCE(
            sc.device,
            CASE 
                WHEN msi.verified = 0 THEN 'undefined'
                WHEN msi.verified = 1 THEN 'desktop'
                WHEN msi.verified = 2 THEN 'app'
                WHEN msi.verified IN (4,5,6) THEN 'mobile'
                ELSE 'tablet'
            END,
            'undefined'
        ) AS device_calculated
    FROM {{ ref('s__attributes__store_core__ref') }} sc
    LEFT JOIN {{ ref('merchant__attributes__store_info__ref') }} msi
        ON sc.store_id = msi.store_id
),

-- ============================================
-- SELECT FINAL: Consolidación de todas las fuentes
-- ============================================
final_data_base AS (
    SELECT 
        -- Store ID (PK)
        sc.store_id,
        
        -- ============================================
        -- INFO Y CONTACTO
        -- Optimización: JOINs directos en lugar de CTE store_info
        -- ============================================
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
        si.phone_whatsapp_button AS whatsapp_button,
        
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
        -- Optimización: Campos directos en lugar de CTE ql_models
        -- ============================================
        ql.predicted_prob AS new_payment_probability,
        cutoff.cutoff AS cutoff_ql,
        
        -- ============================================
        -- BLOCKED FRAUD TAG
        -- ============================================
        COALESCE(bf.blocked_fraud_tag, 0) AS blocked_fraud_tag,
        
    FROM {{ ref('s__attributes__store_core__ref') }} sc
    -- Optimización: JOINs directos en lugar de CTE store_info
    INNER JOIN {{ ref('s__attributes__store_identity__ref') }} si ON sc.store_id = si.store_id
    -- Optimización: Orden de JOINs optimizado - tablas pequeñas primero
    LEFT JOIN onboarding_tags ot ON sc.store_id = ot.store_id  -- Muy pequeño (solo tags específicos)
    LEFT JOIN blocked_fraud bf ON sc.store_id = bf.store_id  -- Pequeño (solo stores bloqueados)
    LEFT JOIN {{ ref('marketing__models__quality_leads__ref') }} ql
        ON sc.store_id = ql.store_id
    LEFT JOIN store_core_with_device_for_cutoff scd
        ON sc.store_id = scd.store_id
    LEFT JOIN {{ source('int_data_predictors', 'marketing_cutoffs_table') }} cutoff
        ON scd.country_code = cutoff.country
        AND ql.model_id = cutoff.model_id
        AND (cutoff.device IS NULL OR cutoff.device = scd.device_calculated)
    LEFT JOIN attribution att ON sc.store_id = att.store_id  -- Mediano
    LEFT JOIN layout l ON sc.store_id = l.store_id  -- Mediano
    LEFT JOIN products p ON sc.store_id = p.store_id  -- Mediano
    LEFT JOIN payments pay ON sc.store_id = pay.store_id  -- Mediano
    LEFT JOIN shipping sh ON sc.store_id = sh.store_id  -- Mediano
    LEFT JOIN {{ ref('s__lifecycle__store_status__ref') }} ls ON sc.store_id = ls.store_id  -- Grande
    LEFT JOIN admin_access aa ON sc.store_id = aa.store_id  -- Grande (métricas agregadas)
    LEFT JOIN storefront_sessions ss ON sc.store_id = ss.store_id  -- Grande (métricas agregadas)
    LEFT JOIN orders_gmv og ON sc.store_id = og.store_id  -- Grande (métricas agregadas)
    LEFT JOIN plan_movements pm ON sc.store_id = pm.store_id  -- Grande (cálculos complejos)
    {% if is_incremental() %}
    -- Optimización: LEFT JOIN en lugar de NOT IN para mejor rendimiento y manejo de NULLs
    LEFT JOIN existing_data ed_check ON sc.store_id = ed_check.store_id
    -- Optimización: LEFT JOIN en lugar de IN para mejor rendimiento
    LEFT JOIN stores_with_changes swc ON sc.store_id = swc.store_id
    {% endif %}
    WHERE sc.created_at >= '{{ var("onboarding_start_date") }}'
        -- Nota: s__attributes__store_core__ref ya filtra tiendas con state = 4 en su post_hook
    {% if is_incremental() %}
        -- Solo procesar tiendas que realmente cambiaron:
        -- 1. Tiendas nuevas (no existen en la tabla)
        -- 2. Tiendas dentro de ventanas activas (pueden cambiar métricas históricas)
        --    Ventana más larga: 90 días (día 0 al día 90 inclusive = 91 días totales)
        -- 3. Tiendas con cambios detectados en fuentes upstream (timestamps)
        AND (
            -- Tiendas nuevas (optimizado: LEFT JOIN ... IS NULL en lugar de NOT IN)
            ed_check.store_id IS NULL
            -- O tiendas dentro de ventanas activas (hasta día 91 para asegurar cálculo completo del día 90)
            OR DATEDIFF(DAY, sc.created_at, CURRENT_DATE) <= 91
            -- O tiendas con cambios detectados en fuentes upstream (optimizado: LEFT JOIN ... IS NOT NULL en lugar de IN)
            OR swc.store_id IS NOT NULL
        )
    {% endif %}
),

-- Agregar hash después de que los alias estén disponibles
final_data AS (
    SELECT 
        *,
        -- ============================================
        -- HASH para detectar cambios en valores
        -- Optimización: Usa macro para evitar duplicación de código
        -- ============================================
        {{ calculate_onboarding_row_hash() }} AS row_hash
    FROM final_data_base
),
{% if is_incremental() %}
-- Comparar hash con datos existentes para evitar UPDATEs innecesarios
-- Optimización: Usa macro para evitar duplicación de código
existing_with_hash AS (
    SELECT 
        store_id,
        {{ calculate_onboarding_row_hash() }} AS existing_hash
    FROM {{ this }}
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

