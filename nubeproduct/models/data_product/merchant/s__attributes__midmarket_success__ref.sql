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
Data Product: Mid Market Success (SILVER REF)
Description: Información consolidada de Mid Market Success por tienda (is_midmarket, rep)
Owner: jhu.boggio@tiendanube.com
Domain: merchant

Este modelo consume desde el intermediate _int__attributes__midmarket_success que contiene toda la lógica
de consolidación de datos. Este modelo solo maneja la incrementalidad y los campos de auditoría.

✅ Materialización INCREMENTAL:
   - Procesa tiendas nuevas y existentes con cambios en información de Mid Market Success
   - Estrategia MERGE con unique_key=store_id
   - Actualiza registros cuando cambian is_midmarket o rep
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
    SELECT
        ms.store_id,
        ms.is_midmarket,
        ms.rep
    FROM {{ ref('_int__attributes__midmarket_success') }} ms
    WHERE
        ms.store_id IN (SELECT store_id FROM {{ ref('s__attributes__store_core__ref') }})
    {% if not is_incremental() %}
        AND ms.change_timestamp >= DATE '1900-01-01'
    {% endif %}
    {% if is_incremental() %}
        AND ms.change_timestamp > (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }})
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

