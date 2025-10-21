{{
    config(
        materialized='incremental',
        unique_key=['cart_id', 'store_id', 'event'],
        partition_by = 'base_date',
        on_schema_change='fail',
        tags=["product","daily-1am"]
    )
}}

-- 1. CTE para obtener el ÚLTIMO evento dentro del periodo procesado
--    El uso de ROW_NUMBER() en este contexto de incrementalidad cambia, 
--    ya que solo queremos procesar el 'evento más reciente' dentro del lote.
WITH latest_events AS (
SELECT
    CAST(element_at(attributes, 'cart_id') AS BIGINT) AS cart_id,
    store_id,
    event,
    element_at(attributes, 'methodname') AS payment_method_name,
    element_at(attributes, 'methodtype') AS payment_method_type,
    element_at(attributes, 'integrationtype') AS payment_method_integration_type,
    element_at(attributes, 'code') AS shipping_method_code,
    element_at(attributes, 'type') AS shipping_method_type,
    element_at(attributes, 'method') AS shipping_method_id,
    element_at(attributes, 'feature') AS payment_retry_feature,
    timestamp AS event_timestamp, -- Necesitamos el timestamp para el filtro incremental
    -- Creamos una columna para el partitioning si fuera necesario
    CAST(timestamp AS DATE) AS base_date, 
    -- Se recomienda mantener la partición si es posible para eficiencia en la tabla de destino
    ROW_NUMBER() OVER (
        PARTITION BY CAST(element_at(attributes, 'cart_id') AS BIGINT), event, store_id 
        ORDER BY timestamp DESC
    ) AS rn -- Identifica el evento más reciente dentro del batch actual
FROM 
    {{ source('stg_storefronts', 'events') }} ev 
WHERE 
    -- Aplicamos la lógica de incrementalidad de fecha
    {% if is_incremental() %}
        -- Cargamos solo los datos posteriores al evento MÁS reciente que ya tenemos en la tabla final.
        -- Esto es eficiente porque no necesitamos la ventana retrospectiva ya que siempre queremos el ÚLTIMO.
        timestamp {{ get_max_date(this, 'base_date', 1, 'month') }}
    {% else %}
        -- Lógica de primera carga (usando tu filtro original de 60 días)
        timestamp BETWEEN DATE('2025-07-01') AND DATE('2025-07-31') 
    {% endif %}
    AND event IN (
        'checkout_selected_shipping_method', 
        'checkout_selected_payment_method',
        'checkout_payment_retry'
    )
    -- Aseguramos que solo procesamos los eventos con cart_id válido.
    AND CAST(element_at(attributes, 'cart_id') AS BIGINT) IS NOT NULL 
    and (
        element_at(attributes, 'methodname') is not null
        or element_at(attributes, 'methodtype') is not null
        or element_at(attributes, 'integrationtype') is not null
        or element_at(attributes, 'code') is not null
        or element_at(attributes, 'type') is not null
        or element_at(attributes, 'method') is not null
        or element_at(attributes, 'feature') is not null
    )
)

-- 2. Seleccionamos el evento MÁS RECIENTE dentro del periodo cargado (rn=1)
--    y lo usamos para el MERGE
SELECT 
    cart_id,
    store_id,
    event,
    payment_method_name,
    payment_method_type,
    payment_method_integration_type,
    shipping_method_code,
    shipping_method_type,
    shipping_method_id,
    payment_retry_feature,
    event_timestamp,
    base_date,
    CURRENT_TIMESTAMP AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    CURRENT_TIMESTAMP AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM 
    latest_events 
WHERE 
    rn = 1