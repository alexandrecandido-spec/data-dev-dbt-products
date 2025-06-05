WITH affiliate_landing_pages AS (
	SELECT
		matt.id
		, matt.landing_page
	FROM {{source('int_moltres', 'mwp_attribution')}} matt
	--Includes only records associated with affiliate landing pages
	WHERE position('%gclid%' IN  matt.landing_page ) > 0
),
subteam_inputs AS (
	SELECT				
    ai.utm_source			
    , ai.utm_medium
    , ai.utm_campaign							
    , ai.utm_content				
    , ai.team				
    , ai.subteam				
	FROM {{ ref('inputs_marketing_attribution') }} ai					
	--Includes only records associated with subteams
	WHERE ai.input_type = 'SUBTEAM_MKT'			
	AND ai.state = 'open'
),
utm_inputs AS (
SELECT				
    lower(ai.utm_source) AS source				
    , lower(ai.utm_medium) AS medium				
    , ai.team AS source_mkt				
    , ai.subteam				
	FROM {{ ref('inputs_marketing_attribution') }} ai					
	--Includes only records associated with UTM campaigns
	WHERE ai.input_type = 'UTM'			
	AND ai.state = 'open'
),
referrer_inputs AS (
	SELECT	
    referrer		
    , ai.team				
    , ai.subteam				
	FROM {{ ref('inputs_marketing_attribution') }} ai					
	--Includes only records associated with referrers landing pages
	WHERE ai.input_type = 'REFERRER'			
	AND ai.state = 'open'
),
insti_inputs AS (
	SELECT				
    ai.landing_page_domain				
    , ai.landing_page_path				
    , ai.team				
    , ai.subteam				
	FROM {{ ref('inputs_marketing_attribution') }} ai					
	--Includes only records associated with INSTI landing pages
	WHERE ai.input_type = 'INSTI'			
	AND ai.state = 'open'	
),
urls_inputs AS (
	SELECT				
    ai.landing_page_domain,				
    ai.landing_page_path,				
    ai.team,				
    ai.subteam				
	FROM {{ ref('inputs_marketing_attribution') }} ai			
	--Includes only records associated with URLs landing pages
	WHERE ai.input_type = 'URL'			
	AND ai.state = 'open'					
)

SELECT
att.*
, CASE					
	WHEN att.referrer_domain = 'direct' AND att.landing_page_domain IN ('partners.tiendanube.com','partners.nuvemshop.com.br')				
		AND att.source IS NULL AND att.medium IS NULL AND att.campaign IS NULL THEN 'Partners'			
	WHEN att.source IN ('yahoo', 'google', 'bing') AND att.medium = 'organic'
        AND (position(urls.landing_page_path IN att.landing_page_path) > 0)				
        AND (position(urls.landing_page_domain IN att.landing_page_domain) > 0) THEN urls.team					
	WHEN aflp.landing_page IS NOT NULL AND (position('%/partners/%' IN att.landing_page_path) > 0) THEN 'Affiliates'
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
	WHEN utms.source_mkt = 'Performance' AND (att.source IN ('google','bing') AND (position('%-brand%' IN att.campaign) > 0)) THEN 'Performance Brand'		
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
        AND (position('%max-perf%' IN att.campaign) > 0) THEN 'Google pMax'			
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
FROM {{ref('_int_marketing_store_attribution__get_store_partner_info')}} att
LEFT JOIN affiliate_landing_pages aflp ON att.click_id = aflp.id
LEFT JOIN referrer_inputs referrer ON position(referrer.referrer IN att.referrer_domain) > 0														
LEFT JOIN subteam_inputs sub ON position(sub.utm_campaign IN att.campaign) > 0	AND  position(sub.utm_source IN att.source) > 0	AND position(sub.utm_medium IN att.medium) > 0 	
LEFT JOIN utm_inputs utms ON att.source = utms.source AND att.medium = utms.medium
LEFT JOIN urls_inputs urls ON position(urls.landing_page_path IN att.landing_page_path) > 0	AND position(urls.landing_page_domain IN att.landing_page_domain) > 0
LEFT JOIN insti_inputs gii ON position(gii.landing_page_path IN att.landing_page_path) > 0	AND position(gii.landing_page_domain IN att.landing_page_domain) > 0