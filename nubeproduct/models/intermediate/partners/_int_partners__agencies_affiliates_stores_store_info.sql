WITH tag_acquired_by AS
(
    SELECT
        store_id,
        MAX(CASE WHEN tag = 'partner' THEN 1 ELSE 0 END) AS has_partner_tag,
        MAX(CASE WHEN tag = 'channels-affiliate-attribution' THEN 1 ELSE 0 END) AS has_affiliate_tag
    FROM 
        (
            SELECT DISTINCT
                related_id AS store_id,
                tag
            FROM {{ source('int_moltres', 'mwp_tags') }}
            WHERE type = 'store'
                AND tag IN ('partner', 'channels-affiliate-attribution')
        )
    GROUP BY store_id
),
blocked_partner_stores AS
(
    SELECT DISTINCT
        related_id AS store_id 
    FROM {{ source('int_moltres', 'mwp_tags') }}
    WHERE tag IN
                (
                    'sre-block-store-404',
                    'sre-block-store-429',
                    'fraud-partner',
                    'partner_bloqued',
                    'partner-blocked'
                )
),
store_info_data AS 
(
    SELECT 
        store_id,
        domain,
        state,
        country AS country_code,
        current_segment,
        first_payment,
        churned_at,
        created_at,
        plan AS plan_id,
        verified,
        main_user_id,
        partner_id,
        partnership_type,
        CASE 
            WHEN verified = 0 THEN 'undefined'
            WHEN verified = 1 THEN 'desktop'
            WHEN verified = 2 THEN 'app'
            WHEN verified IN (4,5,6) THEN 'mobile'
        ELSE 'tablet'
        END AS device,
        CASE 
            WHEN current_segment NOT IN ('no-seller', 'struggling-seller') THEN 'Active merchants' 
            WHEN current_segment IS NULL THEN 'Other'
        ELSE 'Non-active merchants' 
        END AS merchant_type,
        IF(current_segment NOT IN ('no-seller', 'struggling-seller'),TRUE,FALSE) AS active_merchant_flg,
        CASE 
            WHEN first_payment < DATE('2022-06-22')
                AND first_payment IS NOT NULL 
            THEN TRUE
            WHEN first_payment >= DATE('2022-06-22') 
                AND first_payment IS NOT NULL 
                AND 
                    (
                        churned_at IS NULL 
                            OR 
                        DATE_TRUNC('MONTH', first_payment) < DATE_TRUNC('MONTH', churned_at)
                    ) 
            THEN TRUE 
        ELSE FALSE 
        END AS first_payment_flg
    FROM {{ ref('moltres__mwp_store_info') }}
    WHERE partner_id IS NOT NULL -- Partner related
        AND partnership_type IN('store_development', 'affiliate') -- Agencies and affiliates
)
SELECT 
    SI.store_id,
    SI.domain,
    SI.state,
    IF(BPS.store_id IS NOT NULL, TRUE, FALSE) AS block_flg,
    SI.country_code,
    SI.current_segment,
    SI.first_payment,
    SI.first_payment_flg,
    FSD.first_seller_at,
    SI.churned_at,
    SI.created_at,
    SI.plan_id,
    OGP.grupo AS plan_group,
    OGP.namev2 AS plan_name,
    SI.verified,
    SI.main_user_id,
    SI.partner_id,
    SI.partnership_type,
    SI.device,
    CASE 
        WHEN SI.partnership_type = 'affiliate'
        THEN 'Affiliate'
        WHEN TAB.has_partner_tag = 1 
            AND TAB.has_affiliate_tag = 0
        THEN 'Partner'
    ELSE 'Nuvemshop'
    END AS acquired_by,
    QL.predicted_prob,
    MCT.cutoff AS prod_cutoff,
    IF(QL.predicted_prob >= MCT.cutoff,TRUE,FALSE) AS quality_lead_flg,
    SI.merchant_type,
    SI.active_merchant_flg
FROM store_info_data AS SI
LEFT JOIN tag_acquired_by AS TAB
    ON SI.store_id = TAB.store_id
LEFT JOIN {{ ref('data_predictors__quality_leads') }} AS QL
    ON SI.store_id = QL.store_id
LEFT JOIN {{ source('int_data_predictors', 'marketing_cutoffs_table') }} AS MCT 
    ON SI.country_code = MCT.country 
        AND QL.model_id = MCT.model_id 
        AND (MCT.device = SI.device OR MCT.device IS NULL)
LEFT JOIN blocked_partner_stores AS BPS
    ON SI.store_id = BPS.store_id
LEFT JOIN {{ ref('operations_grouping_plans') }} AS OGP
    ON SI.plan_id = OGP.plan   
LEFT JOIN {{ ref('marketing_first_seller_date') }} AS FSD  
    ON SI.store_id = FSD.store_id