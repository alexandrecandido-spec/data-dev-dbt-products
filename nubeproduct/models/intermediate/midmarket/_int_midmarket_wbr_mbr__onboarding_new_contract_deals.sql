with ranked_deals AS (
    SELECT 
        deal_id,
        store_id,
        dealstage,
        type_of_onboarding,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY closedate DESC) AS rn
    FROM {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
        LEFT JOIN {{ source('int_hubspot', 'deals_archived') }} da
            ON d.deal_id = da.id
    WHERE 
        pipeline IN ('Onboarding | AR', 'Onboarding | BR', 'Onboarding | MX')
        AND da.archived IS DISTINCT FROM true
)

SELECT 
    store_id,
    'onboarding' as deal_type
FROM 
    ranked_deals
WHERE 
    rn = 1
    and dealstage in ('Transition to Customer Success', 'Go Live')
    and type_of_onboarding in ('New Project', 'Migration')