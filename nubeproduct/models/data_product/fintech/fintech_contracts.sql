{{
    config(
        materialized='table',
        unique_key='id',
        on_schema_change='fail',
        tags=["daily-9am-4pm"]
    )
}}

WITH contracts_with_policy_classification AS (
    SELECT 
        cwo.*,
        CASE 
            WHEN cwo.portfolio_type = 'renegotiation' 
            THEN CAST(date_trunc('month', cwo.reneg_offer_date) AS DATE)
            ELSE CAST(date_trunc('month', o.evaluation_date) AS DATE) 
        END AS evaluation_month,
        CASE 
            WHEN cwo.portfolio_type = 'renegotiation' 
            THEN cwo.reneg_policy 
            ELSE p.policy 
        END AS policy,
        CASE 
            WHEN cwo.portfolio_type = 'renegotiation' 
            THEN cwo.reneg_risk_classification 
            ELSE o.risk_classification 
        END AS risk_classification
    FROM {{ ref('int_fintech_contracts_with_offer_id') }} cwo
    LEFT JOIN {{ source('dp_credito', 'engine_offers') }} o ON cwo.engine_offer_id = o.id
    LEFT JOIN {{ source('dp_credito', 'policies') }} p ON p.id_policy = o.policy_id
)
SELECT 
    id,
    hub_contract_id,
    quotation_id,
    borrower_document,
    borrower_name,
    disbursed_at,
    disbursed_month,
    created_at,
    updated_at,
    finished_at,
    first_installment_at,
    last_installment_at,
    status,
    portfolio_type,
    installments_number,
    operation_total_taxes_amount,
    operation_total_costs_amount,
    operation_gross_amount,
    operation_net_amount,
    interest_monthly_rate,
    lending_hub,
    payer_id,
    original_contract_ids,
    store_id,
    collection_strategy,
    payer_state,
    engine_offer_id,
    evaluation_link_type,
    custom_status,
    evaluation_month,
    risk_classification,
    policy,
    concat(
        array_join(
            transform(
                split(policy, ' '),
                x -> substring(x, 1, 1)
            ),
            ''
        ),
        risk_classification
    ) AS policy_classification,
    'data-dev-dbt-products' AS sys_audit_created_by,
    CURRENT_TIMESTAMP AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    CURRENT_TIMESTAMP AS sys_audit_updated_on
FROM contracts_with_policy_classification cwo
    