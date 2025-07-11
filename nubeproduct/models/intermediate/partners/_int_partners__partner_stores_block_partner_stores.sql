SELECT DISTINCT
    related_id AS store_id 
FROM curated.moltres.mwp_tags
WHERE tag IN
            (
                'sre-block-store-404',
                'sre-block-store-429',
                'fraud-partner',
                'partner_bloqued',
                'partner-blocked'
            )