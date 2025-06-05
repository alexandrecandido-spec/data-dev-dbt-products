WITH blocked_stores AS (
	SELECT
	distinct related_id,
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
, msi.created_at
, msi.first_payment
, msi.churned_at
, msi.device
, msi.register_url
, msi.partner_id
, msi.partnership_type
, msi.new_payment_probability
, msi.prod_cutoff
, CASE WHEN bls.blocked_store_tag IS NOT NULL THEN 1
     WHEN pf.fraude = 1 THEN 1
	 ELSE 0 END AS blocked_fraud_tag
, CASE WHEN msi.partner_id IS NOT NULL AND p.code = partners.partner_code THEN CONCAT('Affiliates - ' ,partners.team)					
	WHEN msi.partner_id IS NOT NULL AND msi.partnership_type = 'affiliate' THEN 'Affiliates'				
	WHEN msi.partner_id IS NOT NULL AND msi.partnership_type = 'store_development' THEN 'Partners' ELSE 'No' END AS flag_affiliate
, CASE WHEN partners.partner_code IS NOT NULL THEN 1 ELSE 0 END AS flag_partner_exception
, CASE WHEN partners.partner_code IS NOT NULL THEN partners.team ELSE NULL END AS partner_team
, CASE WHEN partners.partner_code IS NOT NULL THEN partners.subteam ELSE NULL END AS partner_subteam
, afc.affiliate_classification AS affiliate_type
, CASE WHEN att.order = att.quantity THEN 1 ELSE 0 END AS trials_last_click
, CASE WHEN att.order = 1 THEN 1 ELSE 0 END  AS trials_first_click
, 1/cast(att.quantity AS FLOAT) AS trials_mean_click
FROM {{source('int_attribution', 'store_attribution')}} att
INNER JOIN {{ ref('_int_marketing_store_info__get_quality_leads_info') }} msi ON att.store_id = msi.store_id						
LEFT JOIN {{source('int_ecosystem', 'mwp_partners')}} p ON msi.partner_id = p.id
LEFT JOIN blocked_stores bls ON att.store_id = bls.related_id
LEFT JOIN partner_fraud_data pf ON p.code = pf.partner_code	
LEFT JOIN affiliates_classification_inputs afc ON p.code = afc.affiliate_code						
LEFT JOIN partner_exceptions_inputs partners ON p.code = partners.partner_code
		