{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
    )
}}

/*
Data Product: Admin Access Metrics (GOLD)
Description: Métricas de accesos al panel de administración por tienda en diferentes períodos de tiempo
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Business Use: Dashboard de onboarding - métricas de engagement con el admin

Spec: Cuenta total de accesos al admin en ventanas de tiempo desde la creación de la tienda.
      Agrega eventos de acceso usando SUM para calcular métricas por ventanas temporales.

✅ Materialización INCREMENTAL:
   - Procesa todas las tiendas (nuevas y existentes) para actualizar métricas cuando hay nuevos accesos
   - Estrategia MERGE con unique_key=store_id
   - Actualiza métricas cuando hay nuevos accesos dentro de las ventanas temporales (7d, 15d, 30d, 60d)

✅ Fuentes: Consume desde staging (marketing__product_marketing__admin_access__event), outputs en Unity Catalog (data_marketing)

⚠️ NOTA: blocked_fraud_tag NO se calcula aquí, se consume del GOLD final desde s__lifecycle__store_status__ref
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    a.store_id,
    -- Total de accesos en diferentes períodos desde creación de la tienda
    SUM(CASE WHEN DATEDIFF(DAY, s.created_at, a.created_at) <= 7 THEN 1 ELSE 0 END) AS qty_admin_access_7d,
    SUM(CASE WHEN DATEDIFF(DAY, s.created_at, a.created_at) <= 15 THEN 1 ELSE 0 END) AS qty_admin_access_15d,
    SUM(CASE WHEN DATEDIFF(DAY, s.created_at, a.created_at) <= 30 THEN 1 ELSE 0 END) AS qty_admin_access_30d,
    SUM(CASE WHEN DATEDIFF(DAY, s.created_at, a.created_at) <= 60 THEN 1 ELSE 0 END) AS qty_admin_access_60d,
    -- Fechas de primer y último acceso
    MIN(a.created_at) AS first_date_admin_access,
    MAX(a.created_at) AS last_date_admin_access,
    
    -- Métricas de platform access desde current_date (rolling windows)
    -- Total histórico de accesos
    COUNT(1) AS all_platform_sessions,
    -- Accesos en los últimos 30 días desde current_date
    SUM(CASE WHEN DATEDIFF(DAY, a.created_at, current_date) <= 30 THEN 1 ELSE 0 END) AS platform_sessions_30,
    -- Accesos en los últimos 90 días desde current_date
    SUM(CASE WHEN DATEDIFF(DAY, a.created_at, current_date) <= 90 THEN 1 ELSE 0 END) AS platform_sessions_90,
    -- Última fecha de acceso (alias para compatibilidad)
    MAX(a.created_at) AS platform_last_access,
    
    -- Auditoría
    MAX(COALESCE(ed.sys_audit_created_on, current_timestamp)) AS sys_audit_created_on,
    MAX(COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products')) AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    
FROM {{ ref('marketing__product_marketing__admin_access__event') }} a 
INNER JOIN {{ ref('s__attributes__store_core__ref') }} s 
    ON s.store_id = a.store_id
LEFT JOIN existing_data ed ON a.store_id = ed.store_id
{% if is_incremental() %}
    -- Procesar todas las tiendas (nuevas y existentes)
    -- MERGE actualizará las métricas cuando hay nuevos accesos dentro de las ventanas temporales
    -- No aplicamos filtro adicional para permitir actualización de tiendas existentes
{% endif %}
GROUP BY a.store_id

