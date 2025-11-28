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
Data Product: GMV Rolling Windows by Store (GOLD AGG)
Description: GMV y órdenes en ventanas rolling (30, 60, 90, 360 días desde hoy) por tienda
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Sub-domain: product_marketing
Business Use: Propiedades de HubSpot y análisis de información de usuarios/tiendas

Este modelo consume desde el intermediate _int__product_marketing__gmv_rolling_windows_store que contiene toda la lógica
de cálculo. Este modelo solo maneja la incrementalidad y los campos de auditoría.

✅ Materialización INCREMENTAL:
   - Procesa tiendas nuevas y existentes con cambios en órdenes
   - Estrategia MERGE con unique_key=store_id
   - **Recalcula diariamente todas las tiendas** porque las ventanas rolling dependen de CURRENT_DATE
   - El change_timestamp incluye CURRENT_DATE para forzar recálculo diario incluso sin nuevas órdenes
   - Filtra órdenes con total_in_usd <= 10000 (ya aplicado en g__operations__orders_gmv_store__agg_daily)
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
    SELECT
        gmv.store_id,
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
        gmv.orders360
    FROM {{ ref('_int__product_marketing__gmv_rolling_windows_store') }} gmv
    WHERE
        gmv.store_id IN (SELECT store_id FROM {{ ref('s__attributes__store_core__ref') }})
    {% if not is_incremental() %}
        AND gmv.change_timestamp >= DATE '1900-01-01'
    {% endif %}
    {% if is_incremental() %}
        -- Filtro incremental: procesa tiendas donde la fecha de change_timestamp >= fecha del último update
        -- Como change_timestamp incluye CURRENT_DATE, todas las tiendas se procesan diariamente
        -- Usamos DATE() para comparar solo fechas (no horas) y asegurar recálculo diario
        AND DATE(gmv.change_timestamp) >= COALESCE(
            (SELECT DATE(MAX(sys_audit_updated_on)) FROM {{ this }}),
            DATE '1900-01-01'
        )
    {% endif %}
)

SELECT
    sd.*,
    -- Auditoría
    COALESCE(ed.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data sd
LEFT JOIN existing_data ed ON sd.store_id = ed.store_id

