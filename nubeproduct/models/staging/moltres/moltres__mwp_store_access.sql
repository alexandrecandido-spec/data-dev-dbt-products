{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags=["marketing","daily_7am"]
    )
}}

/*
Staging Model: Store Admin Access Events
Description: Eventos de acceso al panel de administración por tienda
Owner: jhu.boggio@tiendanube.com
Domain: marketing

Este modelo filtra y prepara los datos de mwp_store_access para consumo en modelos GOLD.
Solo incluye accesos de tiendas creadas después de 2024-01-01.
*/

WITH store_access AS (
    SELECT 
        a.id,
        a.store_id,
        a.created_at
    FROM {{ source('stg_moltres', 'mwp_store_access') }} a
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON s.store_id = a.store_id
        AND s.created_at > '2024-01-01'
    {% if is_incremental() %}
    WHERE a.created_at >= (
        SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
        FROM {{ this }}
    )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    sa.id,
    sa.store_id,
    sa.created_at,
    COALESCE(ed.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM store_access AS sa
LEFT JOIN existing_data ed ON sa.id = ed.id

