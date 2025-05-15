{{
    config(
        materialized='incremental',
        unique_key='id',
        tags=["daily-morning"]
    )
}}

SELECT 
        c.id as id,
        c.hub_contract_id,
        c.quotation_id,
        c.borrower_document,
        c.borrower_name,
        CAST(c.disbursed_at AS DATE) AS disbursed_at,
        p.collection_strategy,
        p.state as payer_state,
        CAST(date_trunc('month', c.disbursed_at) AS DATE) AS disbursed_month,
        CAST(c.created_at AS DATE) AS created_at,
        CAST(c.updated_at AS DATE) AS updated_at,
        CAST(c.finished_at AS DATE) AS finished_at,
        CAST(c.first_installment_at AS DATE) AS first_installment_at,
        CAST(c.last_installment_at AS DATE) AS last_installment_at,
        c.status,
        CASE
            WHEN c.original_contract_id IS NOT NULL
              OR c.hub_contract_id IN ('566774','668824','691318') THEN 'renegotiation'
            ELSE 'general'
        END AS portfolio_type,
        c.installments_number,
        CAST(p.external_id AS INT) AS store_id,
        CAST(c.operation_total_taxes_amount AS DECIMAL(18,4)) / 100 AS operation_total_taxes_amount,
        CAST(c.operation_total_costs_amount AS DECIMAL(18,4)) / 100 AS operation_total_costs_amount,
        CAST(c.operation_gross_amount AS DECIMAL(18,4)) / 100 AS operation_gross_amount,
        CAST(c.operation_net_amount AS DECIMAL(18,4)) / 100 AS operation_net_amount,
        c.interest_monthly_rate,
        c.lending_hub,
        c.payer_id,
        c.original_contract_id
    FROM {{ source('stg_credits', 'contracts') }} c
    LEFT JOIN {{ source('stg_credits', 'payers') }} p ON p.id = c.payer_id