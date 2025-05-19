{{
    config(
        materialized='table',
        unique_key='id',
        on_schema_change='fail',
        tags=["fintech", "daily-9am", "daily-4pm"]
    )
}}

SELECT 
        cwo.*, 
        CAST(date_trunc('month', o.evaluation_date) AS DATE) AS evaluation_month,
        o.risk_classification, 
        p.policy,
        CONCAT(
            regexp_replace(policy, '[^A-Za-z0-9]', ''), 
            o.risk_classification
        ) AS policy_classification,
        'data-dev-dbt-products' AS sys_audit_created_by,
        CURRENT_TIMESTAMP AS sys_audit_created_on,
        'data-dev-dbt-products' AS sys_audit_updated_by,
        CURRENT_TIMESTAMP AS sys_audit_updated_on
    FROM {{ ref('int_fintech_contracts_with_offer_id') }} cwo
    LEFT JOIN {{ source('dp_credito', 'engine_offers') }} o ON cwo.engine_offer_id = o.id
    LEFT JOIN {{ source('dp_credito', 'policies') }} p ON p.id_policy = o.policy_id