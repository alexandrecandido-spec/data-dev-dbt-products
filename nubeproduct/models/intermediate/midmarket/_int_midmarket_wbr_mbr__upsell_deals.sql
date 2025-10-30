with ranked_deals AS (
    SELECT 
        deal_id,
        store_id,
        dealstage,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY closedate DESC) AS rn
    FROM {{ source('int_third_party', 'midmarket_hubspot_deals') }} d
        LEFT JOIN {{ source('int_hubspot', 'deals_archived') }} da
            ON d.deal_id = da.id
    WHERE 
        pipeline IN ('Upsell Success | BR', 'Upsell Success | AR')
        AND da.archived IS DISTINCT FROM true
        AND dealstage IN ('Upsell', 'Won')
)

SELECT 
    store_id,
    'upsell' as deal_type
FROM 
    ranked_deals
WHERE 
    rn = 1