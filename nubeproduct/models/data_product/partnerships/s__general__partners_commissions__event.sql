{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['commission_id'],
        on_schema_change = 'fail',
        tags = ['daily-10am']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['commission_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
commissions AS 
(
    SELECT 
        commission_id,
        partner_id,
        store_id,
        plan_id,
        partner_ledger_entry_type_id,
        partner_ledger_entry_type_name,
        transaction_type,
        commission_type,
        commission_amount,
        partner_commission_percentage,
        plan_value,
        partner_currency,
        store_currency,
        currency_exchange_rate,
        commission_status,
        commission_created_date,
        commission_paid_date,
        partner_ledger_change_timestamp
    FROM {{ ref('_int_partners__partners_commissions_construction') }} 
)
SELECT 
    commissions.* EXCEPT(partner_ledger_change_timestamp), 
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM commissions
LEFT JOIN existing_data e ON commissions.commission_id = e.commission_id

{% if is_incremental() %}
WHERE commissions.partner_ledger_change_timestamp > (
    SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
    FROM {{ this }}
)
{% endif %}