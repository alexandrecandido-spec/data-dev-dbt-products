{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
    )
}}

/*
Data Product: Active Merchant Flag (SILVER REF)
Description: Identifica si una tienda forma parte de la base de clientes pagantes (active merchants)
Owner: jhu.boggio@tiendanube.com
Domain: marketing

Spec: Flag que indica si la tienda está en la lista de active_merchants de la última fecha disponible

✅ Materialización INCREMENTAL:
   - Procesa todas las tiendas (nuevas y existentes) para actualizar el flag cuando cambia el estado
   - Estrategia MERGE con unique_key=store_id
   - Actualiza el flag cuando una tienda entra o sale de la lista de active merchants

✅ Fuentes: stg_active_merchants.active_merchants, outputs en Unity Catalog (data_marketing)
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by', 'is_active_merchant']) }}
),

-- Obtener la última fecha disponible en active_merchants
last_date_finance AS (
    SELECT 
        MAX(date_id) AS last_date
    FROM {{ source('stg_active_merchants', 'active_merchants') }}
),

-- Obtener tiendas activas de la última fecha disponible
active_finance AS (
    SELECT 
        am.store_id
    FROM {{ source('stg_active_merchants', 'active_merchants') }} am
    INNER JOIN last_date_finance ld 
        ON ld.last_date = am.date_id
    GROUP BY am.store_id
)

SELECT
    s.store_id,
    -- Flag de merchant activo
    MAX(CASE 
        WHEN af.store_id IS NOT NULL THEN 1 
        ELSE 0 
    END) AS is_active_merchant,
    
    -- Auditoría
    ANY_VALUE(COALESCE(ed.sys_audit_created_on, current_timestamp)) AS sys_audit_created_on,
    ANY_VALUE(COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products')) AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    
FROM {{ ref('s__attributes__store_core__ref') }} s
LEFT JOIN active_finance af ON s.store_id = af.store_id
LEFT JOIN existing_data ed ON s.store_id = ed.store_id
WHERE s.created_at > '2024-01-01'
{% if is_incremental() %}
    -- Procesar todas las tiendas (nuevas y existentes)
    -- MERGE actualizará el flag cuando cambie el estado (entra o sale de active merchants)
    -- No aplicamos filtro adicional para permitir actualización de tiendas existentes
{% endif %}
GROUP BY s.store_id

