{{
    config(
        materialized='table',
        unique_key=['hub_contract_id', 'initial_due_at'],
        on_schema_change='fail',
        tags=["fintech", "daily-9am-4pm"]
    )
}}

WITH initial_installments AS (
    SELECT
        i.contract_id,
        i.hub_contract_id AS hub_contract_id,
        DATE(DATE_TRUNC('month', i.original_due_at)) AS initial_due_month,
        DATE(i.original_due_at) AS initial_due_at,
        i.original_amount / 100 AS initial_expected_amount,
        i.principal_amount / 100 AS initial_principal_expected_amount,
        ROW_NUMBER() OVER (
            PARTITION BY i.hub_contract_id, i.number 
            ORDER BY i.created_at ASC
        ) AS rank_installments
    FROM {{ source('stg_nuvem_credito', 'installments') }} i
    LEFT JOIN {{ ref('fintech_contracts') }} c 
        ON c.id = i.contract_id
    WHERE i.number <= c.installments_number
)

SELECT 
    hub_contract_id,
    initial_due_month,
    initial_due_at,
    initial_expected_amount,
    initial_principal_expected_amount,
    'data-dev-dbt-products' AS sys_audit_created_by,
    CURRENT_TIMESTAMP AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    CURRENT_TIMESTAMP AS sys_audit_updated_on
FROM initial_installments
WHERE rank_installments = 1  -- In renegotiations sometimes there are duplicates when the first contract is generated with errors

