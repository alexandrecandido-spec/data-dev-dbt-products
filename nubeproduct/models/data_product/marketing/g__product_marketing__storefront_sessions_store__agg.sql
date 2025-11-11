{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
    )
}}

/*
Data Product: Storefront Sessions Metrics (GOLD)
Description: Métricas de sesiones reales de usuarios finales en storefronts por tienda
Owner: jhu.boggio@tiendanube.com
Domain: marketing

Spec: 
- Sesiones de usuarios finales (excluye merchants, bots, tráfego não-humano)
- Conteo de sesiones únicas en ventanas de tiempo desde creación de la tienda usando COUNT DISTINCT
- Incluye primera sesión registrada
- Fuente única de verdad (SSOT): data_product.s__traffic__session__event (Bárbara Aires)

✅ Materialización INCREMENTAL:
   - Solo procesa tiendas con sesiones nuevas desde última ejecución
   - Recalcula contadores completos para esas tiendas (estrategia MERGE)
   - Reduce tiempo de ejecución de 10+ min a segundos

⚠️ NOTA: 
   - Los datos de s__traffic__session__event están en carga incremental histórica.
     Consultar disponibilidad con: SELECT MAX(base_date) FROM data_product.s__traffic__session__event
   - blocked_fraud_tag NO se calcula aquí, se consume en el GOLD final desde s__lifecycle__store_status__ref
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

-- Identificar tiendas que necesitan actualización (con sesiones nuevas)
{% if is_incremental() %}
stores_to_update AS (
    SELECT DISTINCT sess.store_id
    FROM {{ ref('s__traffic__session__event') }} sess
    WHERE sess.base_date > (
        SELECT COALESCE(MAX(last_processed_date), DATE '2024-01-01')
        FROM {{ this }}
    )
    AND sess.is_end_user = TRUE
),
{% endif %}

session_metrics AS (
    SELECT 
        sess.store_id,
        
        -- Primera sesión registrada en la tienda
        MIN(DATE(sess.session_timestamp)) AS first_store_session,
        
        -- Conteo de SESIONES ÚNICAS por ventana de tiempo desde creación de la tienda
        COUNT(DISTINCT(CASE WHEN DATEDIFF(DAY, s.created_at, sess.session_timestamp) <= 7 THEN sess.session_id ELSE NULL END)) AS store_sessions_7d,
        COUNT(DISTINCT(CASE WHEN DATEDIFF(DAY, s.created_at, sess.session_timestamp) <= 15 THEN sess.session_id ELSE NULL END)) AS store_sessions_15d,
        COUNT(DISTINCT(CASE WHEN DATEDIFF(DAY, s.created_at, sess.session_timestamp) <= 30 THEN sess.session_id ELSE NULL END)) AS store_sessions_30d,
        COUNT(DISTINCT(CASE WHEN DATEDIFF(DAY, s.created_at, sess.session_timestamp) <= 60 THEN sess.session_id ELSE NULL END)) AS store_sessions_60d,
        COUNT(DISTINCT(CASE WHEN DATEDIFF(DAY, s.created_at, sess.session_timestamp) <= 90 THEN sess.session_id ELSE NULL END)) AS store_sessions_90d,
        
        -- Total de sesiones (sin límite de tiempo)
        COUNT(DISTINCT sess.session_id) AS total_store_sessions,
        
        -- Última sesión registrada
        MAX(DATE(sess.session_timestamp)) AS last_store_session,
        
        -- Última fecha de datos procesados (para próximo incremental)
        MAX(sess.base_date) AS last_processed_date

    FROM {{ ref('s__traffic__session__event') }} sess
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s 
        ON s.store_id = sess.store_id
        AND s.created_at >= '2024-01-01'
    WHERE sess.is_end_user = TRUE  -- ✅ Solo usuarios finales
    {% if is_incremental() %}
        AND sess.store_id IN (SELECT store_id FROM stores_to_update)
    {% endif %}
    GROUP BY sess.store_id
)

SELECT 
    sm.store_id,
    
    -- Métricas de sesiones
    sm.first_store_session,
    sm.store_sessions_7d,
    sm.store_sessions_15d,
    sm.store_sessions_30d,
    sm.store_sessions_60d,
    sm.store_sessions_90d,
    sm.total_store_sessions,
    sm.last_store_session,
    sm.last_processed_date,
    
    -- Auditoría
    COALESCE(ed.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM session_metrics sm
LEFT JOIN existing_data ed ON sm.store_id = ed.store_id
