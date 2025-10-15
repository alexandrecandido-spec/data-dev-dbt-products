{{
    config(
        materialized='table',
        unique_key='hub_installment_id',
        on_schema_change='fail',
        tags=["fintech", "daily-4am"]
    )
}}

SELECT
       DATE(data_ref) AS data_ref,
       proposal_id AS hub_contract_id,
       installment_id AS hub_installment_id,
       original_installment_id AS original_hub_installment_id,
       deep_installment_id AS deep_hub_installment_id,
       installment_status,
       DATE(installment_due_date) AS installment_due_date,
       CAST(installment_number AS INTEGER) AS installment_number,
       CAST(installment_base_amount AS DOUBLE) AS installment_base_amount,
       CAST(installment_principal_amount AS DOUBLE) AS installment_principal_amount,
       CAST(installment_interest_amount AS DOUBLE) AS installment_interest_amount,
       CAST(additional_late_fine AS DOUBLE) AS additional_late_fine,
       CAST(additional_late_contract_interest AS DOUBLE) AS additional_late_contract_interest,
       CAST(additional_late_penalty_interest AS DOUBLE) AS additional_late_penalty_interest,
       CAST(additional_late_taxes AS DOUBLE) AS additional_late_taxes,
       CAST(discount_pre_payment AS DOUBLE) AS discount_pre_payment,
       CAST(installment_updated_amount AS DOUBLE) AS installment_updated_amount,
       'data-dev-dbt-products' AS sys_audit_created_by,
       CURRENT_TIMESTAMP AS sys_audit_created_on,
       'data-dev-dbt-products' AS sys_audit_updated_by,
       CURRENT_TIMESTAMP AS sys_audit_updated_on
  FROM {{ source('stg_credito_dev', 'mova_installments_present_value') }}
