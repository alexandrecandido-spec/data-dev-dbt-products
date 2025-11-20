{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily-8am-8pm'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE store_id IN (SELECT store_id FROM {{ ref('merchant__attributes__store_info__ref') }} WHERE state = 4)"
        ]
    )
}}

/*
Data Product: Main Payment Method by GMV (GOLD AGG)
Description: Método de pago principal por GMV para cada tienda (desde 2024-01-01)
Owner: jhu.boggio@tiendanube.com
Domain: merchant

Este modelo consume desde el intermediate _int__attributes__main_payment_method que contiene toda la lógica
de cálculo. Este modelo solo maneja la incrementalidad y los campos de auditoría.

✅ Materialización INCREMENTAL:
   - Procesa tiendas nuevas y existentes con cambios en órdenes
   - Estrategia MERGE con unique_key=store_id
   - Actualiza cuando hay nuevas órdenes que cambian el método principal por GMV
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
    SELECT
        mpm.store_id,
        mpm.main_payment_method,
        mpm.main_payment_method_gmv,
        mpm.main_payment_method_orders,
        mpm.main_payment_method_last_order_date
    FROM {{ ref('_int__attributes__main_payment_method') }} mpm
    WHERE
        mpm.store_id IN (SELECT store_id FROM {{ ref('s__attributes__store_core__ref') }})
    {% if not is_incremental() %}
        AND mpm.change_timestamp >= DATE '1900-01-01'
    {% endif %}
    {% if is_incremental() %}
        AND mpm.change_timestamp > (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }})
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

