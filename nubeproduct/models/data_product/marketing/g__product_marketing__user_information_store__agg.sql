{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
    )
}}

/*
Data Product: User Information Consolidated by Store (GOLD AGG)
Description: Información consolidada de usuario/tienda para uso en HubSpot y otros sistemas
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Sub-domain: product_marketing
Business Use: Propiedades de HubSpot y análisis de información de usuarios/tiendas

Spec: 
- Consolida información de múltiples data products: store core, store identity, midmarket success, 
  main payment method, admin access, layout, gmv rolling windows, active merchants, phone, etc.
- Una fila por store_id
- Agregado a nivel store_id

✅ Materialización INCREMENTAL:
   - Estrategia MERGE con unique_key=store_id
   - Procesa tiendas nuevas y existentes con cambios en fuentes upstream
   - Actualiza cuando hay cambios en cualquiera de las fuentes

⚠️ NOTAS:
   - Este modelo consume de múltiples data products existentes
   - Algunas secciones pueden requerir ajustes según disponibilidad de datos
   - Campos pendientes se irán agregando conforme se completen las secciones
   - PRs pendientes:
     * PR 609: s__attributes__midmarket_success__ref (is_midmarket, am)
     * PR 611: g__attributes__main_payment_method__agg (main_payment_method)
     * PR 608: g__product_marketing__admin_access_store__agg (campos adicionales: all_platform_sessions, platform_sessions_30, platform_sessions_90, platform_last_access)
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

{% if is_incremental() %}
-- Identificar tiendas con cambios en fuentes upstream
stores_with_changes AS (
    SELECT DISTINCT store_id
    FROM (
        -- Cambios en store_core
        SELECT store_id FROM {{ ref('s__attributes__store_core__ref') }}
        WHERE sys_audit_updated_on > (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        )
        
        UNION ALL
        
        -- Cambios en store_identity
        SELECT store_id FROM {{ ref('s__attributes__store_identity__ref') }}
        WHERE sys_audit_updated_on > (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        )
        
        UNION ALL
        
        {# Cambios en midmarket success (PR 609 pendiente) #}
        {# SELECT store_id FROM {{ ref('s__attributes__midmarket_success__ref') }}
        WHERE sys_audit_updated_on > (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        ) #}
        
        UNION ALL
        
        -- Cambios en main payment method
        SELECT store_id FROM {{ ref('g__attributes__main_payment_method__agg') }}
        WHERE sys_audit_updated_on > (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        )
        
        UNION ALL
        
        -- Cambios en admin access
        SELECT store_id FROM {{ ref('g__product_marketing__admin_access_store__agg') }}
        WHERE sys_audit_updated_on > (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        )

        UNION ALL

        -- Cambios en layout
        SELECT store_id FROM {{ ref('s__product_marketing__layout__ref') }}
        WHERE sys_audit_updated_on > (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        )

        UNION ALL

        {# Cambios en GMV Rolling Windows (PR 612 pendiente) #}
        {# SELECT store_id FROM {{ ref('g__product_marketing__gmv_rolling_windows_store__agg') }}
        WHERE sys_audit_updated_on > (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        ) #}
        
        UNION ALL
        
        -- Cambios en store_status (para active merchants)
        SELECT store_id FROM {{ ref('s__lifecycle__store_status__ref') }}
        WHERE sys_audit_updated_on > (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM {{ this }}
        )
    )
),
{% endif %}

-- Base: todas las tiendas desde store_core
base_stores AS (
    SELECT 
        sc.store_id,
        sc.created_at,
        sc.country_code AS country,
        sc.country_code AS region,  -- Region = país (empresa solo en latinoamérica)
        sc.city_name AS city,
        sc.domain AS store_name,
        sc.vertical_name AS vertical
    FROM {{ ref('s__attributes__store_core__ref') }} sc
    {% if is_incremental() %}
    WHERE sc.store_id IN (SELECT store_id FROM stores_with_changes)
        OR sc.store_id NOT IN (SELECT store_id FROM {{ this }})
    {% endif %}
)

SELECT
    bs.store_id,
    
    -- ============================================
    -- STORE CORE INFO
    -- ============================================
    bs.created_at,
    bs.country,
    bs.region,  -- Region = país
    bs.city,
    bs.store_name,
    bs.vertical,
    
    -- ============================================
    -- STORE STATUS (Lifecycle)
    -- ============================================
    -- Campos desde s__lifecycle__store_status__ref
    ss.current_segment,
    ss.first_payment,
    ss.current_plan_name AS store_plan_general,
    ss.current_plan_type AS store_plan,
    -- Campos desde s__general__grouping_plans__ref
    pg.namev2 AS store_plan2,
    -- store_plan_value (monthly) desde mwp_plans_countries
    pc.monthly AS store_plan_value,
    
    -- ============================================
    -- SUCCESS (Mid Market)
    -- ============================================
    -- TEMPORALMENTE COMENTADO PARA TESTS - PR 609 pendiente
    -- COALESCE(mms.is_midmarket, false) AS is_midmarket,
    -- mms.am,
    false AS is_midmarket,  -- Placeholder temporal
    NULL AS am,  -- Placeholder temporal
    
    -- ============================================
    -- LAYOUT
    -- ============================================
    -- Usa s__product_marketing__layout__ref.layout_name que ya tiene la lógica de check_last_install
    -- (ROW_NUMBER ordenado por created_at DESC, rn = 1)
    layout.layout_name,
    
    -- ============================================
    -- MAIN PAYMENT METHOD
    -- ============================================
    -- Nota: Disponible cuando se apruebe PR 611
    mpm.main_payment_method,
    
    -- ============================================
    -- ADMIN ACCESS
    -- ============================================
    -- Campos desde g__product_marketing__admin_access_store__agg
    -- Nota: Estos campos están en PR 608 (pendiente aprobación)
    aa.all_platform_sessions,
    aa.platform_sessions_30,
    aa.platform_sessions_90,
    aa.platform_last_access,
    -- Cálculo derivado: días desde último acceso
    CASE 
        WHEN aa.platform_last_access IS NOT NULL 
        THEN DATEDIFF(DAY, aa.platform_last_access, CURRENT_DATE)
        ELSE NULL 
    END AS days_since_last_platform_access,

    -- ============================================
    -- FACEBOOK PIXEL
    -- ============================================
    -- Desde s__attributes__store_identity__ref
    si.pixel_fb,
    
    -- ============================================
    -- CAPI (Conversions API)
    -- ============================================
    -- Desde s__attributes__store_identity__ref
    si.capi_status,
    
    -- ============================================
    -- 2FA STATUS
    -- ============================================
    -- Desde s__attributes__store_identity__ref
    si.twofa_status,

    -- ============================================
    -- SOCIAL ADS (Google Ads, Merchant Center, Google User, TikTok)
    -- ============================================
    -- Campos desde s__attributes__store_identity__ref
    -- Ya incluyen la lógica de check_last_install (última instalación no eliminada)
    si.google_ads,
    si.google_mc AS merchant_center,  -- google_mc = Google Merchant Center
    si.google_user,
    si.tiktok_ads,

    {# ============================================
    GMV ROLLING WINDOWS (PR 612 pendiente)
    ============================================
    Desde g__product_marketing__gmv_rolling_windows_store__agg
    gmv.gmv30,
    gmv.gmv60,
    gmv.gmv90,
    gmv.gmv360,
    gmv.gmv_dol_30,
    gmv.gmv_dol_60,
    gmv.gmv_dol_90,
    gmv.gmv_dol_360,
    gmv.orders30,
    gmv.orders60,
    gmv.orders90,
    gmv.orders360, #}
    
    -- ============================================
    -- ACTIVE MERCHANTS (Finance)
    -- ============================================
    -- Campos desde s__lifecycle__store_status__ref (agregados por pedido de Gi)
    ss.active_merchant_status,

    -- ============================================
    -- STORE IDENTITY (Contact Information)
    -- ============================================
    -- Campos desde s__attributes__store_identity__ref
    si.store_name AS store_name_from_identity,  -- store_name desde i18n
    si.user_email AS main_user_email,  -- Email del usuario principal (usar este como user_email)
    si.owner_phone_number,
    si.phone_from_footer,
    si.phone_whatsapp_button,
    
    -- ============================================
    -- PERFIT (Nuvem Marketing) - EN HOLD
    -- ============================================
    -- ⚠️ PENDIENTE: Esperando respuesta de Gi sobre dónde obtener active_plan e is_free
    -- Campos desde product__invoicing__store_feature_configuration__event
    -- Perfit = Nuvem Marketing (feature_name contiene 'nuvemmarketing' o 'perfit')
    -- Lógica basada en feature_enabled:
    --   - perfit_active_plan: Si feature_enabled = true → tiene plan activo → 'Yes', si no → 'No'
    --   - perfit_free: Si feature_enabled = false o no existe registro → es free → 'Yes', si feature_enabled = true → no es free → 'No'
    CASE 
        WHEN perfit_feature.feature_enabled = true THEN 'Yes' 
        ELSE 'No' 
    END AS perfit_active_plan,
    CASE 
        WHEN perfit_feature.store_id IS NULL THEN 'No'  -- No existe registro → no hay info sobre si es free
        WHEN perfit_feature.feature_enabled = false THEN 'Yes'  -- Feature deshabilitado → es free
        WHEN perfit_feature.feature_enabled = true THEN 'No'  -- Feature habilitado → no es free
        ELSE 'No'
    END AS perfit_free,
    
    -- ============================================
    -- NEW BUSINESS (Product Activations)
    -- ============================================
    -- ⚠️ PENDIENTE: Verificar si existe merchant.s__lifecycle__product_activation__ref
    -- Campos desde merchant.s__lifecycle__product_activation__ref (según indicación de Gi)
    -- Productos: Nuvem Pago, Nuvem Envio, Nuvem MKT, PDV, Nuvem Chat
    -- TODO: Agregar campos cuando se confirme la existencia del modelo o se cree
    -- pa.nuvem_pago_active,
    -- pa.nuvem_envio_active,
    -- pa.nuvem_mkt_active,
    -- pa.pdv_active,
    -- pa.nuvem_chat_active,
    
    -- ============================================
    -- AUDITORÍA
    -- ============================================
    COALESCE(ed.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM base_stores bs
LEFT JOIN {{ ref('s__attributes__store_identity__ref') }} si 
    ON bs.store_id = si.store_id
{# TEMPORALMENTE COMENTADO PARA TESTS - PR 609 pendiente #}
{# LEFT JOIN {{ ref('s__attributes__midmarket_success__ref') }} mms 
    ON bs.store_id = mms.store_id #}
LEFT JOIN {{ ref('g__attributes__main_payment_method__agg') }} mpm 
    ON bs.store_id = mpm.store_id
LEFT JOIN {{ ref('g__product_marketing__admin_access_store__agg') }} aa 
    ON bs.store_id = aa.store_id
LEFT JOIN {{ ref('s__product_marketing__layout__ref') }} layout
    ON bs.store_id = layout.store_id
{# LEFT JOIN {{ ref('g__product_marketing__gmv_rolling_windows_store__agg') }} gmv
    ON bs.store_id = gmv.store_id #}
LEFT JOIN {{ ref('s__lifecycle__store_status__ref') }} ss 
    ON bs.store_id = ss.store_id
LEFT JOIN {{ ref('s__general__grouping_plans__ref') }} pg 
    ON ss.current_plan_id = pg.plan
LEFT JOIN {{ source('int_moltres', 'mwp_plans_countries') }} pc 
    ON ss.current_plan_id = pc.id
LEFT JOIN (
    -- Perfit (Nuvem Marketing) desde activation products
    SELECT 
        store_id,
        feature_enabled,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY sfc_updated_at DESC) AS rn
    FROM {{ ref('product__invoicing__store_feature_configuration__event') }}
    WHERE LOWER(feature_name) LIKE '%nuvemmarketing%' 
        OR LOWER(feature_name) LIKE '%perfit%'
) perfit_feature
    ON bs.store_id = perfit_feature.store_id 
    AND perfit_feature.rn = 1
LEFT JOIN existing_data ed 
    ON bs.store_id = ed.store_id

