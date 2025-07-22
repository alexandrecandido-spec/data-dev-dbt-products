{{
    config(
        materialized='table',
        unique_key='id',
        on_schema_change='fail',
        tags=["daily-9am-4pm"]
    )
}}

SELECT hub_contract_id,
    first_installment_month,
    calendar_month,
    original_due_date,
    rank_installments,
    original_due_amount,
    principal_due_amount,
    paid_amount,
    principal_paid_amount,
    case when (original_due_amount - paid_amount) < 0 then 0 
         when custom_status = 'finished' and finished_at < original_due_date then 0
    else (original_due_amount - paid_amount) end AS remaining_amount,
    case when (principal_due_amount - principal_paid_amount) < 0 then 0 
    when custom_status = 'finished' and finished_at < original_due_date then 0
    else (principal_due_amount - principal_paid_amount) end AS remaining_principal_amount
    FROM {{ ref('int_credit_vintages') }} 