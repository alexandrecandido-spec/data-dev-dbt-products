{{
    config(
        materialized='table',
        unique_key='id',
        on_schema_change='fail',
        tags=["fintech", "daily-9am-4pm"]
    )
}}

WITH initial_installments AS (
    SELECT
        i.contract_id,
        c.hub_contract_id AS hub_contract_id,
        DATE(DATE_TRUNC('month', i.original_due_at)) AS original_due_month,
        DATE(i.original_due_at) AS original_due_at,
        i.original_amount / 100 AS original_amount,
        i.principal_amount / 100 AS principal_amount,
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
    original_due_month,
    original_due_at,
    original_amount,
    principal_amount
FROM initial_installments
WHERE rank_installments = 1  -- In renegotiations sometimes there are duplicates when the first contract is generated with errors

