{{
    config(
        materialized='incremental',
        unique_key='cart_id',
        on_schema_change='fail',
        partition_by='year_month_code',
        tags=['product','daily-8am']
    )
}}

-- 1. Obtenemos los datos nuevos o actualizados de la fuente
WITH source AS (
    SELECT
        ev.store_id,
        msi.current_segment_name,
        ev.event_timestamp AS event_timestamp,
        mo.completed_at,
        mo.started_checkout_at,
        date_diff(second, mo.started_checkout_at, mo.completed_at) AS started_to_completed_time,
        date_diff(second, mo.started_checkout_at, mo.completed_contact_at) AS started_to_completed_contact_time,
        date_diff(second, mo.completed_contact_at, mo.completed_at) AS completed_contact_to_completed_time,
        date_diff(second, mo.completed_contact_at, ev.event_timestamp) AS completed_contact_to_completed_payment_method,
        mo.completed_contact_at,
        mo.storefront,
        mo.gateway_method,
        mo.gateway,
        mo.device_type,
        CAST(mcpo.sort_type AS STRING) AS sort_type,
        mcpo.created_at, 
        mcpo.updated_at, 
        CASE
            WHEN a.handle IS NOT NULL THEN a.handle
            WHEN mo.gateway = 'testmode' THEN 'custom'
            ELSE mo.gateway
        END AS payment,
        ev.cart_id,
        ev.payment_method_position,
        -- Calculamos la columna de partición (usando completed_at)
        concat(cast(year(mo.completed_at) AS varchar(4)), lpad(cast(month(mo.completed_at) AS varchar(2)), 2, '0')) AS year_month_code
    FROM {{ ref('product__traffic__cart_attributes_payment_selection__event') }} ev
    INNER JOIN {{ ref('orders__mwp_orders') }} mo ON ev.cart_id = mo.id
        AND mo.completed_at IS NOT NULL AND mo.completed_at > date'2024-11-01'
    LEFT JOIN {{ ref('moltres__mwp_apps') }} a ON CONCAT('app_', cast(a.id AS varchar(5))) = mo.gateway
    INNER JOIN {{ ref('product__checkout__mwp_configuration_payment_option__event') }} mcpo ON ev.store_id = mcpo.store_id
    LEFT JOIN {{ ref('company_metrics_merchant_info') }} msi ON ev.store_id = msi.store_id
    
    {% if is_incremental() %}
    -- Filtro incremental: usa 'latest_timestamp' para cargar solo lo que ha cambiado.
    WHERE mcpo.updated_at >= (
        SELECT 
            coalesce(max(sys_audit_updated_on), '1900-01-01') - INTERVAL '1 day' 
        FROM {{ this }} 
    )
    {% endif %}
),

-- 2. Traemos las columnas de auditoría de los datos existentes. Clave: cart_id.
existing_data AS (
    {{ get_existing_data(this, ['cart_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

-- 3. Aplicamos la lógica de auditoría con campos explícitos
final AS (
    SELECT
        s.store_id,
        s.current_segment_name,
        s.event_timestamp,
        s.completed_at,
        s.started_checkout_at,
        s.started_to_completed_time,
        s.started_to_completed_contact_time,
        s.completed_contact_to_completed_time,
        s.completed_contact_to_completed_payment_method,
        s.completed_contact_at,
        s.storefront,
        s.gateway_method,
        s.gateway,
        s.device_type,
        CAST(s.sort_type AS STRING) AS sort_type,
        s.created_at,
        s.updated_at,
        s.payment,
        s.cart_id,
        s.payment_method_position,
        s.year_month_code,
        COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
        COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM source s
    LEFT JOIN existing_data e ON s.cart_id = e.cart_id
)

SELECT * FROM final