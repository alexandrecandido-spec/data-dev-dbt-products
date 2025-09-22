WITH blocked_stores AS (
	SELECT
	DISTINCT related_id,
	'blocked_store' AS blocked_store_tag
	FROM {{ source('int_moltres', 'mwp_tags') }} AS tg
	WHERE tg.type = 'store'
	AND (tg.tag = 'sre-block-store-429' OR tg.tag = 'sre-block-store-404')
)

SELECT
att.store_id
, att.order AS click_order
, att.quantity AS click_qty
, att.click_id
, att.click_timestamp
, CASE 
	WHEN att.source IS NULL AND lower(att.medium) = 'cpc' AND (position('web-search' IN att.campaign) > 0) THEN 'google'
	ELSE lower(att.source) END AS source
, lower(att.medium) AS medium
, lower(att.campaign) AS campaign
, lower(att.content) AS content
, lower(att.referrer_domain) AS referrer_domain
, lower(att.referrer_path) AS referrer_path
, lower(att.landing_page_domain) AS landing_page_domain
, lower(att.landing_page_path) AS landing_page_path
, att.attribution_source
, msi.country
, msi.year_month_day_code
, msi.created_at
, msi.first_payment
, msi.churned_at
, msi.first_seller_at
, greatest(msi.change_timestamp, pf.sys_audit_updated_on, afc.sys_audit_updated_on, partners.sys_audit_updated_on) as change_timestamp
, TRIM(TRAILING ',' FROM
		CASE WHEN pf.id IS NOT NULL THEN 'partner_fraud,' ELSE '' END ||
		CASE WHEN afc.id IS NOT NULL THEN 'affiliate_classification,' ELSE '' END ||
		CASE WHEN partners.id IS NOT NULL THEN 'partner_exception,' ELSE '' END
		) AS input_sources_partners
, msi.device
, msi.register_url
, msi.partner_id
, p.code as partner_code
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
, 1 / att.quantity AS trials_mean_click
FROM {{source('int_attribution', 'store_attributions_external')}} att
INNER JOIN {{ ref('_int_marketing_store_info__get_quality_leads_info') }} msi ON att.store_id = msi.store_id						
LEFT JOIN {{source('int_ecosystem', 'mwp_partners')}} p ON msi.partner_id = p.id
LEFT JOIN blocked_stores bls ON att.store_id = bls.related_id
LEFT JOIN {{ ref('marketing_inputs_attribution__partner_fraud') }} pf ON p.code = pf.partner_code	
LEFT JOIN {{ ref('marketing_inputs_attribution__affiliate_classification') }} afc ON p.code = afc.affiliate_code						
LEFT JOIN {{ ref('marketing_inputs_attribution__partner_exception') }} partners ON p.code = partners.partner_code