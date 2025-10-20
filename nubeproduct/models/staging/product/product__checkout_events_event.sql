{{
    config(
        materialized='incremental',
        unique_key=['cart_id', 'event'],
        partition_by = 'base_date',
        on_schema_change='fail',
        tags=["product","daily-1am"]
    )
}}

-- 1. CTE para filtrar y agregar los eventos en el periodo incremental
WITH filtered_events AS (
SELECT 
    CAST(element_at(attributes, 'cart_id') AS BIGINT) AS cart_id,
    event,
    store_id,
    MIN(timestamp) AS new_first_event_timestamp,
    MAX(timestamp) AS new_last_event_timestamp,
    CAST(MIN(timestamp) AS DATE) AS base_date
FROM 
    {{ source('stg_storefronts', 'events') }} ev 
WHERE 
    -- Aplicamos el filtro de cart_id no nulo
    CAST(element_at(attributes, 'cart_id') AS BIGINT) IS NOT NULL 

    -- Aplicamos la lógica de incrementalidad de fecha
    {% if is_incremental() %}
        -- En ejecuciones incrementales, solo procesa datos nuevos.
        -- Se asume una columna "timestamp" o similar en la tabla fuente que se mapea a "day/month/year"
        -- Se recomienda usar una macro como get_max_date o el filtro de timestamp directo si es posible
        AND timestamp {{ get_max_date(this, 'base_date', 1, 'month') }}
    {% else %}
        AND CAST(timestamp AS DATE) BETWEEN DATE('2025-07-01') AND DATE('2025-07-31') 
    {% endif %}

    -- Filtro de tipos de evento
    AND event IN (
        'checkout_start', 'checkout_filled_email', 'checkout_filled_shipping_zipcode', 
        'checkout_selected_shipping_method', 'checkout_filled_shipping_first_name',
        'checkout_filled_shipping_last_name', 'checkout_filled_shipping_phone', 
        'checkout_clicked_shipping_continue', 'checkout_clicked_shipping_continue_to_payment', 
        'checkout_filled_billing_id_number', 'checkout_checked_billing_same_address',
        'checkout_filled_billing_country', 'checkout_filled_billing_business_name', 
        'checkout_filled_billing_trade_name', 'checkout_filled_billing_state_registration', 
        'checkout_filled_billing_business_activity', 'checkout_selected_payment_method',
        'checkout_clicked_payment_complete_order', 'checkout_order_placed', 'checkout_order_paid'
    )
GROUP BY 1, 2, 3
)

-- 2. CTE para obtener los datos existentes (solo en modo incremental)
{% if is_incremental() %}
, existing_data AS (
    SELECT
        cart_id,
        event,
        first_event_timestamp,
        last_event_timestamp
    FROM
        {{ this }}
)
{% endif %}

-- 3. SELECT final con la lógica de COALESCE y JOIN para el MERGE condicional
SELECT 
    T1.cart_id,
    T1.event,
    T1.store_id,
    
    -- Lógica para first_event_timestamp: Mantiene el antiguo si existe, a menos que sea un cart_id/event totalmente nuevo.
    -- COALESCE(T2.first_event_timestamp, T1.new_first_event_timestamp):
    --   Si ya existía (T2 is not null): usa el valor existente (T2)
    --   Si es nuevo (T2 is null): usa el nuevo valor (T1)
    {% if is_incremental() %}
        COALESCE(T2.first_event_timestamp, T1.new_first_event_timestamp) AS first_event_timestamp,
        coalesce(T1.new_last_event_timestamp, T2.last_event_timestamp) AS last_event_timestamp,
        CAST(COALESCE(T2.first_event_timestamp, T1.new_first_event_timestamp) AS DATE) AS base_date
    {% else %}
        T1.new_first_event_timestamp AS first_event_timestamp,
        T1.new_last_event_timestamp AS last_event_timestamp,
        cast(T1.new_first_event_timestamp as date) AS base_date
    {% endif %}

FROM 
    filtered_events T1
{% if is_incremental() %}
LEFT JOIN 
    existing_data T2 
    ON T1.cart_id = T2.cart_id AND T1.event = T2.event
{% endif %}