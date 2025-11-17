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
, msi.country_code
, CAST(date_format(msi.created_at, 'yyyyMMdd') AS INT) AS year_month_day_code
, msi.created_at
, greatest(msi.sys_audit_updated_on, p.sys_audit_updated_on) as change_timestamp
, TRIM(TRAILING ',' FROM
		CASE WHEN p.affiliate_classification IS NOT NULL THEN 'affiliate_classification,' ELSE '' END ||
		CASE WHEN p.flag_partner_exception = 1 THEN 'partner_exception,' ELSE '' END
		) AS input_sources_partners
, msi.register_url
, msi.partner_id
, msi.partnership_type
, p.flag_partner_exception
, p.partner_exception_team
, p.partner_exception_subteam
, p.affiliate_classification 
--, CASE WHEN msi.partner_id IS NOT NULL AND p.flag_partner_exception=1 THEN CONCAT('Affiliates - ' ,p.partner_exception_team)					
--	WHEN msi.partner_id IS NOT NULL AND msi.partnership_type = 'affiliate' THEN 'Affiliates'				
--	WHEN msi.partner_id IS NOT NULL AND msi.partnership_type = 'store_development' THEN 'Partners' ELSE 'No' END AS flag_affiliate
, CASE WHEN att.order = att.quantity THEN 1 ELSE 0 END AS trials_last_click
, CASE WHEN att.order = 1 THEN 1 ELSE 0 END  AS trials_first_click
, 1 / att.quantity AS trials_mean_click
FROM {{source('int_attribution', 'store_attributions_external')}} att --- tabla de Santi, es el modelo de atribución de store
INNER JOIN {{ ref('s__attributes__store_core__ref') }} msi ON att.store_id = msi.store_id --- store_info adicional						
LEFT JOIN {{ref('s__general__partners_info__ref')}} p ON msi.partner_id = p.partner_id ---- cambiado al data product de partnerships
--LEFT JOIN {{ ref('s__general__mkt_attribution_github_inputs_affiliates_classification__ref') }} afc ON p.partner_code = afc.affiliate_code --- cambiar nombre					
--LEFT JOIN {{ ref('s__general__mkt_attribution_github_inputs_partner_exception__ref') }} partners ON p.partner_code = partners.partner_code --- cambiar nombre