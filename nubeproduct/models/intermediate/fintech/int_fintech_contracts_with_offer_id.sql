WITH renegotiated_credits AS (
    SELECT 
        TRIM(contract_id) AS contract_id
    FROM {{ source('int_nuvem_credito', 'contracts') }} 
    LATERAL VIEW EXPLODE(
        SPLIT(
            REGEXP_REPLACE(original_contract_ids, '\\[|\\]', ''), 
            ','
        )
    ) t AS contract_id
    WHERE original_contract_ids IS NOT NULL
        AND TRIM(contract_id) != ''

    UNION

    SELECT DISTINCT 
        id AS contract_id
    FROM {{ ref('nuvem_credito__credit_proposals') }}
    WHERE hub_contract_id IN ('138981','524183', '290246','205429') --renegs antigas
),
renegotiations AS (
    SELECT DISTINCT 
        cr.num_novo_contrato_reneg AS hub_contract_id, 
        quem_gerou_esta_oferta AS reneg_policy, 
        perfil_reneg AS reneg_risk_classification,
        ro.data_ref AS reneg_offer_date
    FROM {{ source('int_credito', 'renegotiated_contracts') }} cr
    LEFT JOIN {{ source('int_credito', 'renegotiation_offers') }} ro ON cr.id_oferta = ro.id_oferta
)
SELECT 
    c.id,
    c.hub_contract_id,
    c.quotation_id,
    c.borrower_document,
    c.borrower_name,
    c.disbursed_at,
    c.disbursed_month,
    c.created_at,
    c.updated_at,
    c.finished_at,
    c.first_installment_at,
    c.last_installment_at,
    c.status,
    c.portfolio_type,
    c.installments_number,
    c.operation_total_taxes_amount,
    c.operation_total_costs_amount,
    c.operation_gross_amount,
    c.operation_net_amount,
    c.interest_monthly_rate,
    c.lending_hub,
    c.payer_id,
    c.original_contract_ids,
    c.store_id,
    c.collection_strategy,
    c.payer_state,
    COALESCE(o.external_offer_id, hco.offer_id) AS engine_offer_id,
    CASE 
        WHEN o.external_offer_id IS NOT NULL THEN 'New' 
        WHEN o.external_offer_id IS NULL AND hco.offer_id IS NOT NULL THEN 'Historical' 
        ELSE 'Unknown' 
    END AS evaluation_link_type,
    CASE 
        WHEN r.contract_id IS NOT NULL THEN 'renegotiated'
        WHEN c.hub_contract_id = '665436' THEN 'canceled'
        ELSE c.status 
    END AS custom_status,
    rr.reneg_policy,
    rr.reneg_risk_classification,
    rr.reneg_offer_date
FROM {{ ref('nuvem_credito__credit_proposals') }} c
LEFT JOIN {{ source('int_nuvem_credito', 'quotations') }} q ON q.id = c.quotation_id
LEFT JOIN {{ source('int_nuvem_credito', 'offers') }} o ON q.offer_id = o.id
LEFT JOIN {{ source('int_credito', 'historical_credits_offers') }} hco ON c.hub_contract_id = hco.hub_contract_id
LEFT JOIN renegotiated_credits r ON c.id = r.contract_id
LEFT JOIN renegotiations rr ON c.hub_contract_id = rr.hub_contract_id
WHERE c.disbursed_at IS NOT NULL 
    AND c.status IN ('finished', 'paying')