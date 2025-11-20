{{
    config(
        materialized='incremental',
        unique_key='cart_id',
        on_schema_change='fail',
        partition_by='year_month_code',
        tags=['product','daily-8am']
    )
}}

-- CTE 1: Deduplicación y Filtro de Eventos de la Fuente
-- Incluye la lógica de row_number para obtener solo el primer evento por cart_id.
WITH deduped_source AS (
    SELECT
        ev.event_id,
        ev.session_id,
        ev.consumer_id,
        ev.store_id,
        ev.timestamp AS event_timestamp,
        element_at(ev.attributes, 'cart_id') AS cart_id,
        element_at(ev.attributes, 'position') AS payment_method_position,
        -- Columna de partición
        concat(cast(ev.year AS varchar(4)), lpad(cast(ev.month AS varchar(2)), 2, '0')) AS year_month_code,
        -- Usamos ROW_NUMBER para encontrar el primer evento por cart_id
        ROW_NUMBER() OVER (PARTITION BY element_at(ev.attributes, 'cart_id') ORDER BY ev.timestamp ASC) AS rownum
    FROM {{ source('stg_storefronts', 'events') }} ev
    WHERE
        ev.event = 'checkout_selected_payment_method'
        -- Filtro original de la query
        AND (ev.year = 2025 OR (ev.year = 2024 AND ev.month IN (11, 12)))
        
        -- ********** FILTRO INCREMENTAL **********
        {% if is_incremental() %}
        -- Usamos event_timestamp (timestamp del evento) para el filtro incremental
        AND ev.timestamp >= (
            SELECT 
                coalesce(max(sys_audit_updated_on), '1900-01-01') - INTERVAL '1 day' 
            FROM {{ this }} 
        )
        {% endif %}
        -- ****************************************
),

-- CTE 2: Pre-selección de datos a insertar/actualizar
source AS (
    SELECT
        event_id,
        session_id,
        consumer_id,
        store_id,
        event_timestamp,
        cart_id,
        payment_method_position,
        year_month_code
    FROM deduped_source
    WHERE rownum = 1 -- Aplicamos la deduplicación aquí
),

-- CTE 3: Traemos las columnas de auditoría de los datos que ya existen en el destino
-- Usamos la clave primaria: cart_id
existing_data AS (
    {{ get_existing_data(this, ['event_id','session_id','consumer_id','store_id','event_timestamp','cart_id','payment_method_position','year_month_code',
    'sys_audit_created_on', 'sys_audit_created_by']) }}
),

-- CTE 4: Aplicamos la lógica de auditoría
final AS (
    SELECT
        -- COLUMNAS DEL NEGOCIO (traídas de 'source s')
        coalesce(e.event_id, s.event_id) as event_id,
        coalesce(e.session_id, s.session_id) as session_id,
        coalesce(e.consumer_id, s.consumer_id) as consumer_id,
        coalesce(e.store_id, s.store_id) as store_id,
        coalesce(e.event_timestamp, s.event_timestamp) as event_timestamp,
        coalesce(e.cart_id, s.cart_id) as cart_id,
        coalesce(e.payment_method_position, s.payment_method_position) as payment_method_position,
        coalesce(e.year_month_code, s.year_month_code) as year_month_code,

        -- AUDITORÍA CREACIÓN: Preservamos si el registro ya existía (e)
        COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
        COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
        
        -- AUDITORÍA ACTUALIZACIÓN: Actualizamos siempre el updated_on/by
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM source s
    -- Unimos usando la clave primaria (unique_key)
    LEFT JOIN existing_data e ON s.cart_id = e.cart_id
)

SELECT * FROM final