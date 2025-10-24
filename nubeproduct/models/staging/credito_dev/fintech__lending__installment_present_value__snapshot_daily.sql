{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    partition_by=['year_month_day_code'],
    on_schema_change='fail',
    tags=["fintech", "daily-4am"],
    pre_hook=["DELETE FROM {{ this }} WHERE year_month_day_code >= (SELECT coalesce(MAX(CAST(date_format(DATE(data_ref), 'yyyyMMdd') AS INT)), 0) FROM {{ source('stg_credito_dev', 'mova_installments_present_value') }})"]
  )
}}

SELECT
       DATE(data_ref)                                       AS data_ref,
       CAST(proposal_id AS STRING)                          AS hub_contract_id,
       CAST(installment_id AS STRING)                       AS hub_installment_id,
       CAST(original_installment_id AS STRING)              AS original_hub_installment_id,
       CAST(deep_installment_id AS STRING)                  AS deep_hub_installment_id,
       CAST(installment_status AS STRING)                   AS installment_status,  
       DATE(installment_due_date)                           AS installment_due_date,
       CAST(installment_number AS INTEGER)                  AS installment_number,
       CAST(installment_base_amount AS DOUBLE)              AS installment_base_amount,
       CAST(installment_principal_amount AS DOUBLE)         AS installment_principal_amount,
       CAST(installment_interest_amount AS DOUBLE)          AS installment_interest_amount,
       CAST(additional_late_fine AS DOUBLE)                 AS additional_late_fine,
       CAST(additional_late_contract_interest AS DOUBLE)    AS additional_late_contract_interest,
       CAST(additional_late_penalty_interest AS DOUBLE)     AS additional_late_penalty_interest,
       CAST(additional_late_taxes AS DOUBLE)                AS additional_late_taxes,
       CAST(discount_pre_payment AS DOUBLE)                 AS discount_pre_payment,
       CAST(installment_updated_amount AS DOUBLE)           AS installment_updated_amount,
       CAST(date_format(DATE(data_ref), 'yyyyMMdd') AS INT) AS year_month_day_code,
       'data-dev-dbt-products'                              AS sys_audit_created_by,
       CURRENT_TIMESTAMP                                    AS sys_audit_created_on,
       'data-dev-dbt-products'                              AS sys_audit_updated_by,
       CURRENT_TIMESTAMP                                    AS sys_audit_updated_on
  FROM {{ source('stg_credito_dev', 'mova_installments_present_value') }}
  {% if is_incremental() %}
    WHERE cast(date_format(date(data_ref), 'yyyyMMdd') as int) > (select coalesce(max(year_month_day_code), 0) from {{ this }})
  {% endif %}