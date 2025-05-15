{{
    config(
        materialized='incremental',
        unique_key='id',
        tags=["daily-morning"]
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

        current_timestamp AS extraction_date
    FROM {{ ref('int_fintech_contracts_with_offer_id') }} cwo
    LEFT JOIN {{ source('dp_credito', 'engine_offers') }} o ON cwo.engine_offer_id = o.id
    LEFT JOIN {{ source('dp_credito', 'policies') }} p ON p.id_policy = o.policy_id