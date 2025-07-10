SELECT
    SI.store_id,
    SI.main_user_id,
    SI.doimain,
    SI.country_code,
    SI.state,
    SI.current_segment,
    CASE 
	    WHEN SI.current_segment NOT IN ('no-seller', 'struggling-seller') THEN 'Active merchants' 
		WHEN SI.current_segment IS NULL THEN 'Other'
	ELSE 'Non-active merchants' 
	END AS merchant_type,
    IF(SI.current_segment NOT IN ('no-seller', 'struggling-seller'),TRUE,FALSE) AS active_merchant_flg,
    QL.device,
    QL.new_payment_probability,
    QL.prod_cutoff,
    IF(QL.new_payment_probability >= QL.prod_cutoff,TRUE,FALSE) AS quality_lead_flg,
    CASE 
        WHEN SI.first_payment_ts < DATE('2022-06-22')
            AND SI.first_payment_ts IS NOT NULL 
        THEN TRUE
        WHEN SI.first_payment_ts >= DATE('2022-06-22') 
            AND SI.first_payment IS NOT NULL 
            AND 
                (
                    SI.churned_at_ts IS NULL 
                        OR 
                    DATE_TRUNC('MONTH', SI.first_payment_ts) < DATE_TRUNC('MONTH', SI.churned_at_ts)
                ) 
        THEN TRUE 
    ELSE FALSE 
    END AS first_payment_flg
    CASE 
        WHEN SI.partnership_type = 'affiliate'
        THEN 'Affiliate'
        WHEN TAB.has_partner_tag = 1 AND TAB.has_affiliate_tag = 0
        THEN 'Partner'
    ELSE 'Nuvemshop'
    END AS acquired_by,  
    SI.created_at_ts,
    SI.first_payment_ts,
    SI.churned_at_ts,
    SI.plan AS plan_id,
    OGP.grupo AS plan_group,
    OGP.namev2 AS plan_name,
    SI.partner_id,
    SI.partnership_type,
    PI.partner_code,
    PI.partner_name,
    PI.partner_country_code,
    PI.partner_created_at_ts,
    PI.mkt_exclusion,
    PI.affiliate_classification,
    PI.affiliate_tier,
    PI.affiliate_main_platform
FROM {{ ref('_int_partners__partner_stores_store_info') }} AS SI
LEFT JOIN {{ ref('_int_partners__partner_stores_partners_info') }} AS PI
    ON SI.partner_id = PI.partner_id
LEFT JOIN {{ ref('_int_partners__partner_stores_quality_leads') }} AS QL
    ON SI.store_id = QL.store_id
LEFT JOIN {{ ref('_int_partners__partner_stores_tag_acquired_by') }} AS TAB
    ON SI.store_id = TAB.store_id
LEFT JOIN {{ ref('operations_grouping_plans') }} AS OGP
    ON SI.plan = OGP.plan    