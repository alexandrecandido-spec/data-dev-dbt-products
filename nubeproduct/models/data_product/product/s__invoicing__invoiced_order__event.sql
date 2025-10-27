{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['order_id'],
        on_schema_change = 'fail',
        tags = ['daily-8am']
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['order_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

request_data AS (
    SELECT
    *
    FROM (
        SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY request_created_date DESC, invoice_created_date DESC) as rn    
        FROM {{ ref('s__invoicing__invoice_and_request__event') }}
    ) r
    WHERE rn = 1
)

SELECT
    o.order_id,
    o.order_completed_date,    
    o.store_id,
    o.domain,
    o.feature_activation_date,
    o.plan_group,
    o.store_state,
    o.current_segment,
    o.country,
    o.address_state,
    o.tax_regime_code,
    o.tax_regime_name,
    o.registry_status,
    o.cert_valid,
    o.days_to_cert_expire,
    r.request_id as last_request_id,
    r.request_created_date as last_request_created_date,
    r.invoice_type,
    r.request_status as last_request_status,
    r.is_prd_environment,
    r.request_error_group as last_request_error_group,
    r.request_error_code as last_request_error_code,
    r.invoice_status as last_invoice_status,
    r.invoice_created_date as last_invoice_created_date,
    r.invoice_authorized_date as last_invoice_authorized_date,
    r.invoice_cancelled_date as last_invoice_cancelled_date,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int__product__invoicing__orders_after_invoice_configuration') }} o
LEFT JOIN request_data r
    ON o.order_id = r.order_id
LEFT JOIN existing_data e
    ON o.order_id = e.order_id

{% if is_incremental() %}
WHERE COALESCE(o.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
    OR COALESCE(r.sys_audit_updated_on, current_timestamp) >= (
        SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
    )
{% endif %}