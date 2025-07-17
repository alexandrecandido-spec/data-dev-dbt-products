WITH affiliates_external AS 
(
    SELECT DISTINCT 
        MAA.affiliate_code AS partner_code,
        MAA.affiliate_classification,
        MAA.affiliate_tier,
        MAA.affiliate_main_platform,
        MAA.affiliate_country,
        MAB.fraude
    FROM {{ ref('inputs_marketing_attribution') }} AS MAA
    LEFT JOIN {{ ref('inputs_marketing_attribution') }} AS MAB 
        ON MAA.affiliate_code = MAB.partner_code 
            AND MAB.input_type = 'PARTNER_FRAUD'
    WHERE MAA.state = 'open'
        AND MAA.input_type = 'AFFILIATE_LIST'
)
SELECT
    AE.partner_code,
    PE.partner_code AS mkt_exclusion,        
    AE.affiliate_country,
    MIN(AE.affiliate_tier) AS affiliate_tier,
    MIN(AE.affiliate_main_platform) AS affiliate_main_platform,
    MIN(AE.affiliate_classification) AS affiliate_classification
FROM affiliates_external AS AE 
LEFT JOIN {{ ref('marketing_inputs_attribution__partner_exception') }} AS PE 
    ON AE.partner_code = PE.partner_code
GROUP BY 
    AE.partner_code, 
    PE.partner_code, 
    AE.affiliate_country; --- REVIEW