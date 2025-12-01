{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily-7am']
    )
}}

/*
Data Product: User Information Store (GOLD AGG)
Description: Información consolidada de usuario/tienda para uso en HubSpot y otros sistemas
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Sub-domain: product_marketing
Business Use: Propiedades de HubSpot y análisis de información de usuarios/tiendas

Spec: 
- Consolida información de múltiples data products: store core, store identity, midmarket success, 
  main payment method, admin access, layout, etc.
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
     * PR 609: s__attributes__midmarket_success__ref (is_midmarket, rep)
     * PR 611: g__attributes__main_payment_method__agg (main_payment_method)
     * PR 608: g__product_marketing__admin_access_store__agg (campos: all_platform_sessions, platform_sessions_30, platform_sessions_90, platform_last_access)
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
        
        -- Cambios en midmarket success (PR 609 pendiente) - TEMPORALMENTE COMENTADO PARA TESTS
        -- SELECT store_id FROM {{ ref('s__attributes__midmarket_success__ref') }}
        -- WHERE sys_audit_updated_on > (
        --     SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
        --     FROM {{ this }}
        -- )
        
        UNION ALL
        
        -- Cambios en main payment method (PR 611 pendiente)
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
        
        -- Cambios en GMV rolling windows
        SELECT store_id FROM {{ ref('g__product_marketing__gmv_rolling_windows_store__agg') }}
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
    bs.vertical,
    
    -- ============================================
    -- SUCCESS (Mid Market)
    -- ============================================
    -- TEMPORALMENTE COMENTADO PARA TESTS - PR 609 pendiente
    -- COALESCE(mms.is_midmarket, false) AS is_midmarket,
    -- mms.rep,
    false AS is_midmarket,  -- Placeholder temporal
    NULL AS rep,  -- Placeholder temporal
    
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
    -- GMV ROLLING WINDOWS
    -- ============================================
    -- Desde g__product_marketing__gmv_rolling_windows_store__agg
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
    gmv.orders360,
    
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
-- TEMPORALMENTE COMENTADO PARA TESTS - PR 609 pendiente
-- LEFT JOIN {{ ref('s__attributes__midmarket_success__ref') }} mms 
--     ON bs.store_id = mms.store_id
LEFT JOIN {{ ref('g__attributes__main_payment_method__agg') }} mpm 
    ON bs.store_id = mpm.store_id
LEFT JOIN {{ ref('g__product_marketing__admin_access_store__agg') }} aa 
    ON bs.store_id = aa.store_id
LEFT JOIN {{ ref('s__product_marketing__layout__ref') }} layout 
    ON bs.store_id = layout.store_id
LEFT JOIN {{ ref('g__product_marketing__gmv_rolling_windows_store__agg') }} gmv 
    ON bs.store_id = gmv.store_id
LEFT JOIN existing_data ed 
    ON bs.store_id = ed.store_id

