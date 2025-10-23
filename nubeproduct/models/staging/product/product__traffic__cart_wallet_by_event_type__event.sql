{{
    config(
        materialized='incremental',
        unique_key=['cart_id', 'event'],
        partition_by = 'base_date', 
        on_schema_change='fail',
        tags=["product","daily-1am"]
    )
}}

-- 1. CTE para filtrar y obtener el primer evento en el periodo actual
WITH new_first_events AS (
SELECT 
    CAST(element_at(attributes, 'cart_id') AS BIGINT) AS cart_id,
    event,
    MIN(timestamp) AS new_first_event,
    CAST(MIN(timestamp) AS DATE) AS base_date,
    CURRENT_TIMESTAMP AS new_sys_audit_created_on,
    'data-dev-dbt-products' AS new_sys_audit_created_by,
    CURRENT_TIMESTAMP AS new_sys_audit_updated_on,
    'data-dev-dbt-products' AS new_sys_audit_updated_by
FROM 
    {{ source('stg_storefronts', 'events') }} ev 
WHERE 
    -- Aplicamos la lógica de incrementalidad de fecha
    {% if is_incremental() %}
        -- Usaremos la macro get_max_date con una ventana de retrospectiva (ej. 1 mes) 
        -- para capturar datos tardíos, comparando con la base_date de la tabla final.
         timestamp {{ get_max_date(this, 'base_date', 1, 'month') }}
    {% else %}
        -- Lógica de primera carga (tu filtro original de 60 días) 
         timestamp BETWEEN DATE('2025-07-01') AND DATE('2025-07-31') 
            
    {% endif %}

    -- Filtros de negocio
    AND CAST(element_at(attributes, 'cart_id') AS BIGINT) IS NOT NULL 
    AND (
        event = 'wallet_customer_identification' 
        OR 
        (event = 'wallet_customer_login' AND element_at(attributes, 'success')='true')
    )
GROUP BY 1, 2
)

---
-- 2. CTE para obtener los datos existentes (solo en modo incremental)
{% if is_incremental() %}
, existing_data AS (
    SELECT
        cart_id,
        event,
        first_event, -- Columna de la tabla final
        sys_audit_created_on,
        sys_audit_created_by,
        sys_audit_updated_on,
        sys_audit_updated_by
    FROM
        {{ this }}
)
{% endif %}
---

-- 3. SELECT final con la lógica de COALESCE para mantener el MIN antiguo
SELECT 
    T1.cart_id,
    T1.event,
    
    -- Lógica de Primer Evento Fijo:
    -- Mantiene T2.first_event si existe (es el mínimo histórico).
    -- Usa T1.new_first_event si es un cart_id/event nuevo (T2 es NULL).
    {% if is_incremental() %}
        COALESCE(T2.first_event, T1.new_first_event) AS first_event,
    {% else %}
        T1.new_first_event AS first_event,
    {% endif %}
    
    -- La base_date se basa en el MIN final para un particionamiento estable.
    CAST(
        {% if is_incremental() %}
            COALESCE(T2.first_event, T1.new_first_event)
        {% else %}
            T1.new_first_event
        {% endif %}
    AS DATE) AS base_date,
    {% if is_incremental() %}
        coalesce(t2.sys_audit_created_on, t1.new_sys_audit_created_on) as sys_audit_created_on,
        coalesce(t2.sys_audit_created_by, t1.new_sys_audit_created_by) as sys_audit_created_by,
        coalesce(t2.sys_audit_updated_on, t1.new_sys_audit_updated_on) as sys_audit_updated_on,
        coalesce(t2.sys_audit_updated_by, t1.new_sys_audit_updated_by) as sys_audit_updated_by
    {% else %}
        t1.new_sys_audit_created_on as sys_audit_created_on,
        t1.new_sys_audit_created_by as sys_audit_created_by,
        t1.new_sys_audit_updated_on as sys_audit_updated_on,
        t1.new_sys_audit_updated_by as sys_audit_updated_by
    {% endif %}
FROM 
    new_first_events T1
{% if is_incremental() %}
LEFT JOIN 
    existing_data T2 
    ON T1.cart_id = T2.cart_id AND T1.event = T2.event
{% endif %}