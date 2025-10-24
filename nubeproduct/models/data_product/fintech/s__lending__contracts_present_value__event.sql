{{
    config(
        materialized='table',
        on_schema_change='fail',
        tags=["fintech", "daily-10am"],
    )
}}

SELECT
       data_ref,
       store_id,
       hub_contract_id,
       installment_status,
       ROUND(SUM(installment_base_amount), 2) AS contract_base_amount,
       ROUND(SUM(installment_principal_amount), 2) AS contract_principal_amount,
       ROUND(SUM(installment_interest_amount), 2) AS contract_interest_amount,
       ROUND(SUM(additional_late_fine), 2) AS additional_late_fine,
       ROUND(SUM(additional_late_contract_interest), 2) AS additional_late_contract_interest,
       ROUND(SUM(additional_late_penalty_interest), 2) AS additional_late_penalty_interest,
       ROUND(SUM(additional_late_taxes), 2) AS additional_late_taxes,
       ROUND(SUM(discount_pre_payment), 2) AS discount_pre_payment,
       ROUND(SUM(installment_accumulated_amount), 2) AS contract_accumulated_amount,
       ROUND(SUM(installment_updated_amount), 2) AS contract_updated_amount,
       'data-dev-dbt-products' AS sys_audit_created_by,
       CURRENT_TIMESTAMP AS sys_audit_created_on,
       'data-dev-dbt-products' AS sys_audit_updated_by,
       CURRENT_TIMESTAMP AS sys_audit_updated_on
  FROM {{ ref('_int_fintech__installment_present_value') }}
 GROUP BY 1, 2, 3, 4