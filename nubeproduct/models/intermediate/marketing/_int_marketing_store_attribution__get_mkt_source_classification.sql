WITH affiliate_landing_pages AS (
	SELECT
		matt.id
		, matt.landing_page
	FROM {{source('int_moltres', 'mwp_attribution')}} matt
	--Includes only records associated with affiliate landing pages
	WHERE position('gclid' IN  matt.landing_page ) > 0
)

SELECT 
*
FROM (
SELECT
att.*
, CASE					
	WHEN att.referrer_domain = 'direct' AND att.landing_page_domain IN ('partners.tiendanube.com','partners.nuvemshop.com.br')				
		AND att.source IS NULL AND att.medium IS NULL AND att.campaign IS NULL THEN 'Partners'			
	WHEN att.source IN ('yahoo', 'google', 'bing') AND att.medium = 'organic'
        AND (position(urls.landing_page_path IN att.landing_page_path) > 0)				
        AND (position(urls.landing_page_domain IN att.landing_page_domain) > 0) THEN urls.team					
	WHEN aflp.landing_page IS NOT NULL AND (position('/partners/' IN att.landing_page_path) > 0) THEN 'Affiliates'
	WHEN att.source IN ('yahoo', 'google', 'bing') AND att.medium = 'organic'				
		AND (position(gii.landing_page_path IN att.landing_page_path) > 0)
        AND (position(gii.landing_page_domain IN att.landing_page_domain) > 0) THEN gii.team
	WHEN att.source IN ('chatgpt.com', 'claude.ai', 'copilot.microsoft.com')				
		AND (position(urls.landing_page_path IN att.landing_page_path) > 0)
        AND (position(urls.landing_page_domain IN att.landing_page_domain) > 0) THEN urls.team
	WHEN att.source IN ('chatgpt.com', 'claude.ai', 'copilot.microsoft.com')				
		AND (position(gii.landing_page_path IN att.landing_page_path) > 0)
        AND (position(gii.landing_page_domain IN att.landing_page_domain) > 0) THEN gii.team
	WHEN utms.source_mkt = 'Communications' THEN 'Communications'				
	WHEN utms.source_mkt = 'Performance' AND (att.source IN ('google','bing') AND (position('-brand' IN att.campaign) > 0)) THEN 'Performance Brand'		
	WHEN utms.source_mkt = 'Performance' THEN 'Performance No Brand'
	WHEN (att.source = '' OR att.source IS NULL) AND att.referrer_domain = 'direct' 
        AND (position(urls.landing_page_path IN att.landing_page_path) > 0) 
        AND (position(urls.landing_page_domain IN att.landing_page_domain) > 0) THEN urls.team		
	WHEN (att.source = '' OR att.source IS NULL) AND att.referrer_domain = 'direct' AND att.partner_id IS NULL THEN 'Direct'
	WHEN utms.source_mkt IS NULL AND att.partner_id IS NOT NULL AND att.flag_partner_exception = 1 THEN att.partner_team	
	WHEN utms.source_mkt IS NULL AND att.medium = 'direct' AND att.campaign = 'direct' 
        AND (position(urls.landing_page_path IN att.landing_page_path) > 0)
        AND (position(urls.landing_page_domain IN att.landing_page_domain) > 0) THEN urls.team
	WHEN utms.source_mkt IS NULL AND att.medium = 'direct' AND att.campaign='direct' AND att.partner_id IS NULL 
        AND (position(referrer.referrer IN att.referrer_domain) > 0) THEN 'Growth'		
	WHEN utms.source_mkt IS NULL AND att.medium = 'direct' AND att.campaign = 'direct' AND att.partner_id IS NULL THEN 'Direct'				
	WHEN utms.source_mkt IS NULL AND (att.referrer_domain = 'direct' OR (att.medium = 'direct' )) AND att.partner_id IS NULL THEN 'Direct'			
	WHEN utms.source_mkt IS NULL AND att.partner_id IS NOT NULL AND att.partnership_type = 'affiliate' THEN 'Affiliates'				
	WHEN utms.source_mkt IS NULL AND att.partner_id IS NOT NULL AND att.partnership_type = 'store_development' THEN 'Partners'				
	WHEN utms.source_mkt IS NULL AND att.source = 'youtube' AND att.medium = 'social' 
        AND (position(urls.landing_page_path IN att.landing_page_path) > 0)
        AND (position(urls.landing_page_domain IN att.landing_page_domain) > 0) THEN urls.team				
	WHEN (att.source = '' OR att.source IS NULL) AND (att.medium = '' OR att.medium IS NULL) AND att.partner_id IS NULL THEN 'Others'				
	WHEN utms.source_mkt IS NULL THEN 'Others'				
	ELSE utms.source_mkt END AS mkt_source
, CASE					
	WHEN utms.source_mkt = 'Performance' AND att.source = 'google' 
        AND (position('max-perf' IN att.campaign) > 0) THEN 'Google pMax'			
	WHEN utms.source_mkt = 'Performance' AND att.source IN ('google','bing') 
        AND (position(sub.utm_campaign IN att.campaign) > 0) THEN sub.subteam				
	WHEN utms.source_mkt = 'Product Marketing' 
        AND (position(sub.utm_campaign IN att.campaign) > 0) THEN sub.subteam				
	WHEN att.source = 'google' AND att.medium = 'organic' AND att.referrer_domain = 'gemini.google.com' THEN 'AI'				
	WHEN att.source = 'chatgpt.com' AND att.medium = '' THEN 'AI'				
	WHEN utms.subteam IS NULL AND mkt_source = sub.team 
        AND (position(sub.utm_campaign IN att.campaign) > 0) THEN sub.subteam		
	WHEN utms.subteam IS NULL AND mkt_source = urls.team 
        AND (position(urls.landing_page_path IN att.landing_page_path) > 0)
        AND (position(urls.landing_page_domain IN att.landing_page_domain) > 0) THEN urls.subteam		
	WHEN utms.subteam IS NULL AND mkt_source = gii.team 
        AND (position(gii.landing_page_path IN att.landing_page_path) > 0)
        AND (position(gii.landing_page_domain IN att.landing_page_domain) > 0) THEN gii.subteam
	WHEN utms.subteam IS NULL AND mkt_source = referrer.team 
        AND (position(referrer.referrer IN att.referrer_domain) > 0) THEN referrer.subteam	
	WHEN utms.subteam IS NULL AND mkt_source = att.partner_team AND att.flag_partner_exception = 1 AND att.partner_id IS NOT NULL THEN att.partner_subteam
    WHEN aflp.landing_page IS NOT NULL 
        AND (position('/partners/' IN att.landing_page_path) > 0) THEN att.affiliate_type
    WHEN utms.subteam IS NULL AND att.partner_id IS NOT NULL AND att.partnership_type = 'affiliate' THEN att.affiliate_type
	WHEN utms.source_mkt IS NULL THEN mkt_source				
	WHEN utms.subteam IS NOT NULL THEN utms.subteam				
	ELSE mkt_source END AS mkt_subteam
, ROW_NUMBER() OVER (PARTITION BY att.store_id, att.click_id ORDER BY att.click_timestamp DESC) AS rownumber
FROM {{ref('_int_marketing_store_attribution__get_store_partner_info')}} att
LEFT JOIN affiliate_landing_pages aflp ON att.click_id = aflp.id
LEFT JOIN {{ref('_int_marketing_inputs_attribution__utm')}} utms ON att.source = utms.source AND att.medium = utms.medium
LEFT JOIN {{ref('_int_marketing_inputs_attribution__subteam')}} sub ON position(sub.utm_campaign IN att.campaign) > 0	AND  att.source = sub.utm_source AND att.medium = sub.utm_medium	
LEFT JOIN {{ref('_int_marketing_inputs_attribution__referrer')}} referrer ON position(referrer.referrer IN att.referrer_path) > 0														
LEFT JOIN {{ref('_int_marketing_inputs_attribution__url')}}  urls ON position(urls.landing_page_path IN att.landing_page_path) > 0	AND position(urls.landing_page_domain IN att.landing_page_domain) > 0
LEFT JOIN {{ref('_int_marketing_inputs_attribution__insti')}} gii ON position(gii.landing_page_path IN att.landing_page_path) > 0	AND position(gii.landing_page_domain IN att.landing_page_domain) > 0  
)
WHERE rownumber = 1