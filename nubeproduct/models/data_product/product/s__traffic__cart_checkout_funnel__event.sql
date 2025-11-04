-- depends_on: {{ ref('_int_storefronts_sessions_checkout_events_summary') }}
{{
    config(
        materialized='incremental',
        unique_key=['cart_id'],
        partition_by = 'base_date', 
        on_schema_change='fail',
        tags=["daily-1am"]
    )
}}

-- Columnas de la tabla base (i.*) que representan el primer evento y deben ser protegidas
{% set base_timestamp_cols = [
    'checkout_start_timestamp',
    'checkout_filled_email_timestamp',
    'checkout_filled_shipping_zipcode_timestamp',
    'checkout_selected_shipping_method_timestamp',
    'checkout_filled_shipping_first_name_timestamp',
    'checkout_filled_shipping_last_name_timestamp',
    'checkout_filled_shipping_phone_timestamp',
    'checkout_clicked_shipping_continue_timestamp',
    'checkout_clicked_shipping_continue_to_payment_timestamp',
    'checkout_filled_billing_id_number_timestamp',
    'checkout_checked_billing_same_address_timestamp',
    'checkout_filled_billing_country_timestamp',
    'checkout_filled_billing_business_name_timestamp',
    'checkout_filled_billing_trade_name_timestamp',
    'checkout_filled_billing_state_registration_timestamp',
    'checkout_filled_billing_business_activity_timestamp',
    'checkout_selected_payment_method_timestamp',
    'checkout_clicked_payment_complete_order_timestamp',
    'checkout_order_placed_timestamp',
    'checkout_order_paid_timestamp'
] %}

-- Columnas de atributos que también deben ser protegidas (de los LEFT JOINs)
{% set join_attr_cols = [
    'wallet',
    'payment_method_name', 'payment_method_type', 'payment_method_integration_type', 
    'shipping_method_type', 'shipping_method_id', 'shipping_method_code', 
    'payment_retry_feature',
    'first_event', 'first_event_timestamp', 'last_event', 'last_event_timestamp'
] %}

-- 1. CTE para obtener los datos base con el filtro incremental
WITH incremental_base AS (
SELECT 
    i.*,
    i.base_date AS session_base_date, -- Renombramos la columna base_date de la tabla fuente para evitar conflicto
    CURRENT_TIMESTAMP AS new_sys_audit_created_on,
    'data-dev-dbt-products' AS new_sys_audit_created_by,
    CURRENT_TIMESTAMP AS new_sys_audit_updated_on,
    'data-dev-dbt-products' AS new_sys_audit_updated_by
FROM 
    {{ ref('_int_storefronts_sessions_checkout_events_summary') }} i
WHERE
    -- Aplicamos la lógica de incrementalidad de fecha
    {% if is_incremental() %}
         i.base_date >= (select DATE_SUB(max(base_date), 60) from {{ this }})
         and i.base_date < (select DATEADD(day,30,max(base_date)) from {{ this }})
    {% else %}
        -- Lógica de primera carga (ajusta el rango según sea necesario)
         i.base_date BETWEEN DATE('2025-01-01') AND DATE('2025-01-31') 
    {% endif %}
    
    AND i.cart_id IS NOT NULL 
)

-- 2. CTE para realizar todos los JOINS y transformaciones
, joined_data AS (
SELECT 
    i.* EXCEPT(base_date), -- Excluimos la base_date original para usar la renombrada
    i.base_date, -- Renombrada de i.base_date
    CASE 
        WHEN we.wallet_customer_login = 1 THEN 'Wallet logged'
        WHEN we.wallet_customer_identification = 1 THEN 'Wallet Exposed'
        ELSE 'Not Wallet' 
    END AS new_wallet,
    cesa_payment.payment_method_name AS new_payment_method_name,
    cesa_payment.payment_method_type AS new_payment_method_type,
    cesa_payment.payment_method_integration_type AS new_payment_method_integration_type,
    cesa_shipping.shipping_method_type AS new_shipping_method_type,
    cesa_shipping.shipping_method_id AS new_shipping_method_id,
    cesa_shipping.shipping_method_code AS new_shipping_method_code,
    cesa_retry.payment_retry_feature AS new_payment_retry_feature,
    sscfl.first_event AS new_first_event,
    sscfl.first_event_timestamp AS new_first_event_timestamp,
    sscfl.last_event AS new_last_event,
    sscfl.last_event_timestamp AS new_last_event_timestamp
FROM 
    incremental_base i
LEFT JOIN {{ ref('_int_product_storefronts_sessions_wallet_events') }} we ON i.cart_id = we.cart_id
LEFT JOIN {{ ref('product__traffic__cart_attributes_by_event_type__event') }} cesa_shipping 
    ON i.cart_id = cesa_shipping.cart_id AND cesa_shipping.event = 'checkout_selected_shipping_method'
LEFT JOIN {{ ref('product__traffic__cart_attributes_by_event_type__event') }} cesa_payment 
    ON i.cart_id = cesa_payment.cart_id AND cesa_payment.event = 'checkout_selected_payment_method'
LEFT JOIN {{ ref('product__traffic__cart_attributes_by_event_type__event') }} cesa_retry 
    ON i.cart_id = cesa_retry.cart_id AND cesa_retry.event = 'checkout_payment_retry'
LEFT JOIN {{ ref('_int_storefronts_sessions_checkout_first_and_last_event') }} sscfl 
    ON i.cart_id = sscfl.cart_id
)

---
-- 3. CTE para obtener los datos existentes
{% if is_incremental() %}
, existing_data AS (
    SELECT
        cart_id, 
        base_date,
        -- Columnas de TIMESTAMP de la tabla base
        {% for col in base_timestamp_cols %}
        {{ col }},
        {% endfor %}
        -- Columnas de atributos de los JOINs
        {% for col in join_attr_cols %}
        {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %} ,
        sys_audit_created_on,
        sys_audit_created_by,
        sys_audit_updated_on,
        sys_audit_updated_by
    FROM
        {{ this }}
    WHERE cart_id IN (SELECT cart_id FROM joined_data)
)
{% endif %}
---

-- 4. SELECT final con la lógica de COALESCE para 'Primer Visto Gana'
SELECT 
    -- 4.1 Columnas de Cart/Store (claves, deben actualizarse o no cambian)
    T1.cart_id,
    T1.store_id,

    -- 4.2 Lógica 'Primer Visto Gana' para TIMESTAMPS de la capa base (i.*)
    {% if is_incremental() %}
        {% for col in base_timestamp_cols %}
        COALESCE(T2.{{ col }}, T1.{{ col }}) AS {{ col }},
        {% endfor %}
    {% else %}
        {% for col in base_timestamp_cols %}
        T1.{{ col }} AS {{ col }},
        {% endfor %}
    {% endif %}
    
    -- 4.3 Lógica 'Primer Visto Gana' para ATRIBUTOS de los JOINs
    {% if is_incremental() %}
        {% for col in join_attr_cols %}
        COALESCE(T2.{{ col }}, T1.new_{{ col }}) AS {{ col }},
        {% endfor %}
    {% else %}
        {% for col in join_attr_cols %}
        T1.new_{{ col }} AS {{ col }},
        {% endfor %}
    {% endif %}

    -- 4.4 Columna de particionamiento (base_date, debe ser estable)
    {% if is_incremental() %}
        COALESCE(T2.base_date, T1.base_date) AS base_date
    {% else %}
        T1.base_date
    {% endif %}
    ,
    -- 4.5 Columnas de auditoria
    {% if is_incremental() %}
        COALESCE(T2.sys_audit_created_on, T1.new_sys_audit_created_on) AS sys_audit_created_on,
        COALESCE(T2.sys_audit_created_by, T1.new_sys_audit_created_by) AS sys_audit_created_by,
        T1.new_sys_audit_updated_on as sys_audit_updated_on,
        T1.new_sys_audit_updated_by as sys_audit_updated_by
    {% else %}
        T1.new_sys_audit_created_on as sys_audit_created_on,
        T1.new_sys_audit_created_by as sys_audit_created_by,
        T1.new_sys_audit_updated_on as sys_audit_updated_on,
        T1.new_sys_audit_updated_by as sys_audit_updated_by
    {% endif %}
FROM 
    joined_data T1
{% if is_incremental() %}
LEFT JOIN 
    existing_data T2 
    ON T1.cart_id = T2.cart_id
{% endif %}