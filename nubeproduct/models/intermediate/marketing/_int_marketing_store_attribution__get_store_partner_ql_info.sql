WITH blocked_stores AS (
	SELECT
	related_id,
	'blocked_store' as blocked_store_tag
	FROM {{ source('int_moltres', 'mwp_tags') }} as tg
	WHERE tg.type = 'store'
	AND (tg.tag = 'sre-block-store-429' OR tg.tag = 'sre-block-store-404')
),
partner_fraud_data AS (
	SELECT				
    ai.partner_code,
    ai.fraude			
	FROM {{ ref('inputs_marketing_attribution') }} ai	
	--Includes only records associated with partners tagged as fraud			
	WHERE ai.input_type = 'PARTNER_FRAUD'	
	AND ai.state = 'open'	
),
affiliates_classification_inputs AS (
	SELECT				
    ai.affiliate_code,				
    MIN(ai.affiliate_classification) AS affiliate_classification				
	FROM {{ ref('inputs_marketing_attribution') }} ai	
	--Includes only records associated with affiliate classification		
	WHERE ai.input_type = 'AFFILIATE_LIST'
	AND ai.state = 'open'				
	GROUP BY 1		
),
partner_exceptions_inputs AS (
	SELECT				
	ai.partner_code				
	, ai.team				
	, ai.subteam				
	FROM {{ ref('inputs_marketing_attribution') }} ai					
	--Includes only records associated with partners not related to affiliate team
	WHERE ai.input_type = 'PARTNER_CODE'			
	AND ai.state = 'open'
)

SELECT
att.store_id
, att.order as click_order
, att.quantity as click_qty
, att.click_id
, att.click_timestamp
, lower(att.source) AS source
, lower(att.medium) AS medium
, lower(att.campaign) AS campaign
, lower(att.content) AS content
, att.referrer_domain
, att.referrer_path
, att.landing_page_domain
, att.landing_page_path
, att.attribution_source
, msi.country
, DATE(msi.created_at) AS created_at
, DATE(msi.first_payment) AS first_payment
, DATE(msi.churned_at) AS churned_at
, CASE WHEN msi.verified = 0 THEN 'undefined' 
     WHEN msi.verified = 1 THEN 'desktop'						
	 WHEN msi.verified = 2 THEN 'app'			
     WHEN msi.verified IN (4,5,6) THEN 'mobile'	
     ELSE 'tablet' END AS device
, msi.register_url
, msi.partner_id
, p.code AS partner_code
, msi.partnership_type
, CASE WHEN bls.blocked_store_tag IS NOT NULL THEN 1
     WHEN pf.fraude = 1 THEN 1
	 ELSE 0 END AS blocked_fraud_tag
, CASE WHEN msi.partner_id IS NOT NULL AND p.code = partners.partner_code THEN CONCAT('Affiliates - ' ,partners.team)					
	WHEN msi.partner_id IS NOT NULL AND msi.partnership_type = 'affiliate' THEN 'Affiliates'				
	WHEN msi.partner_id IS NOT NULL AND msi.partnership_type = 'store_development' THEN 'Partners' ELSE 'No' END AS flag_affiliate
, afc.affiliate_classification AS affiliate_type
, np.predicted_prob as new_payment_probability
, tb_cff.cutoff AS prod_cutoff
FROM {{source('int_attribution', 'store_attribution')}} att
INNER JOIN {{ ref('moltres__mwp_store_info') }} msi ON att.store_id = msi.store_id						
LEFT JOIN {{source('int_ecosystem', 'mwp_partners')}} p ON msi.partner_id = p.id
LEFT JOIN blocked_stores bls ON att.store_id = bls.related_id
LEFT JOIN partner_fraud_data pf ON p.code = pf.partner_code	
LEFT JOIN affiliates_classification_inputs afc ON p.code = afc.affiliate_code						
LEFT JOIN partner_exceptions_inputs partners ON p.code = partners.partner_code
LEFT JOIN {{ ref('_int_marketing__quality_leads') }} np ON att.store_id = np.store_id							
LEFT JOIN {{ source('int_data_predictors', 'marketing_cutoffs_table') }} tb_cff ON msi.country = tb_cff.country	AND np.model_id = tb_cff.model_id			
                                                                                AND (tb_cff.device = device OR tb_cff.device IS NULL)		