WITH temp AS    
(
    SELECT DISTINCT
        related_id AS store_id,
        tag
    FROM {{ source('int_moltres', 'mwp_tags') }}
    WHERE type = 'store'
        AND tag IN ('partner', 'channels-affiliate-attribution')
)
SELECT
    store_id,
    MAX(CASE WHEN tag = 'partner' THEN 1 ELSE 0 END) AS has_partner_tag,
    MAX(CASE WHEN tag = 'channels-affiliate-attribution' THEN 1 ELSE 0 END) AS has_affiliate_tag
FROM temp
GROUP BY store_id
