{{
    config(
        materialized='table',
        unique_key=['hub_contract_id', 'initial_due_date'],
        on_schema_change='fail',
        tags=["daily-9am-4pm"]
    )
}}

SELECT hub_contract_id,
    first_installment_month,
    calendar_month,
    initial_due_date,
    rank_installments,
    initial_expected_amount,
    initial_principal_expected_amount,
    paid_amount,
    original_paid_amount,
    principal_paid_amount,
    case when (initial_expected_amount - original_paid_amount) < 0 then 0 
    else (initial_expected_amount - original_paid_amount) end AS initial_unpaid_amount,
    case when (initial_principal_expected_amount - principal_paid_amount) < 0 then 0 
    else (initial_principal_expected_amount - principal_paid_amount) end AS initial_principal_unpaid_amount,
    'data-dev-dbt-products' AS sys_audit_created_by,
    CURRENT_TIMESTAMP AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    CURRENT_TIMESTAMP AS sys_audit_updated_on
    FROM {{ ref('int_credit_vintages') }} 