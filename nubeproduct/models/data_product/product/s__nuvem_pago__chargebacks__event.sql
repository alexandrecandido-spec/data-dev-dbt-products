{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['cbk_id'],
        partition_by=['cbk_year_month_code'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

SELECT
cbk_id,
store_id,
order_id,
cbk_events,
cbk_amount,
cbk_chargeback,
cbk_customer,
cbk_deadline,
cbk_created_at,
order_paid_at,
cbk_reason,
cbk_status,
cbk_failure_reason,
cbk_order_number,
cbk_origin,
cbk_payment_method,
cbk_remaining_amount_to_refund,
order_cbk_status,
cbk_year_month_code,
country,
domain,
state,
current_segment,
plan_name,
current_timestamp AS sys_audit_created_on,
'data-dev-dbt-products' AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int__product__nuvem_pago_chargebacks') }} c
   {% if is_incremental() %}
WHERE c.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}
