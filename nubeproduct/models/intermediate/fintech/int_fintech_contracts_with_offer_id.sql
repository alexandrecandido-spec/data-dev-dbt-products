WITH renegociaciones AS (
    SELECT DISTINCT original_contract_id AS contract_id
    FROM {{ ref('nuvem_credito__credit_proposals') }}
    WHERE original_contract_id IS NOT NULL

    UNION ALL

    SELECT DISTINCT id AS contract_id
    FROM {{ ref('nuvem_credito__credit_proposals') }}
    WHERE hub_contract_id IN ('138981','524183')
)
    SELECT 
        c.*, 
        COALESCE(o.external_offer_id, hco.offer_id) AS engine_offer_id,
        CASE 
            WHEN o.external_offer_id IS NULL THEN 'Historical' 
            ELSE 'New' 
        END AS evaluation_link_type,
        CASE 
            WHEN r.contract_id IS NOT NULL THEN 'renegotiated'
            WHEN c.hub_contract_id = '290246' THEN 'renegotiated'
            WHEN c.hub_contract_id = '665436' THEN 'canceled'
            ELSE c.status 
        END AS custom_status
    FROM {{ ref('nuvem_credito__credit_proposals') }} c
    LEFT JOIN {{ source('int_nuvem_credito', 'quotations') }} q ON q.id = c.quotation_id
    LEFT JOIN {{ source('int_nuvem_credito', 'offers') }} o ON q.offer_id = o.id
    LEFT JOIN {{ source('int_credito', 'historical_credits_offers') }} hco ON c.hub_contract_id = hco.hub_contract_id
    LEFT JOIN renegociaciones r ON c.id = r.contract_id
    WHERE c.disbursed_at IS NOT NULL AND c.status IN ('finished', 'paying')