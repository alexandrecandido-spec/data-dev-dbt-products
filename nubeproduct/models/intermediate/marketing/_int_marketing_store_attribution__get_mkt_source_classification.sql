WITH affiliate_landing_pages AS (
	SELECT
		matt.id
		, matt.landing_page
	FROM {{source('int_moltres', 'mwp_attribution')}} matt
	--Includes only records associated with affiliate landing pages
	WHERE position('gclid' IN  matt.landing_page ) > 0
),

base_classification AS (
    SELECT
        att.*
		, aflp.landing_page AS aflp_landing_page
        , utms.source_mkt AS utms_source_mkt
        , utms.subteam AS utms_subteam
        , sub.utm_campaign AS sub_utm_campaign
        , sub.subteam AS sub_subteam
        , sub.team AS sub_team
        , urls.landing_page_path AS urls_landing_page_path
        , urls.landing_page_domain AS urls_landing_page_domain
        , urls.team AS urls_team
        , urls.subteam AS urls_subteam
        , gii.landing_page_path AS gii_landing_page_path
        , gii.landing_page_domain AS gii_landing_page_domain
        , gii.team AS gii_team
        , gii.subteam AS gii_subteam
        , referrer.referrer 
        , referrer.team AS referrer_team
        , referrer.subteam AS referrer_subteam
		, greatest(att.change_timestamp, utms.sys_audit_updated_on, sub.sys_audit_updated_on, referrer.sys_audit_updated_on, urls.sys_audit_updated_on, gii.sys_audit_updated_on) as change_timestamp_incremental
		, TRIM(TRAILING ',' FROM
							CONCAT_WS(',',
								CASE WHEN utms.id IS NOT NULL THEN 'utm' END,
								CASE WHEN sub.id IS NOT NULL THEN 'subteam' END,
								CASE WHEN referrer.id IS NOT NULL THEN 'referrer' END,
								CASE WHEN urls.id IS NOT NULL THEN 'url' END,
								CASE WHEN gii.id IS NOT NULL THEN 'insti' END,
								att.input_sources_partners
							)
							) AS input_sources
        -- Cálculo de mkt_source en esta capa
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
			WHEN position('chatgpt' IN att.source) > 0 THEN 'Organic'
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
			WHEN utms.source_mkt IS NULL AND att.medium = 'affiliates' THEN 'Affiliates'			
			WHEN (att.source = '' OR att.source IS NULL) AND (att.medium = '' OR att.medium IS NULL) AND att.partner_id IS NULL THEN 'Others'				
			WHEN utms.source_mkt IS NULL THEN 'Others'				
			ELSE utms.source_mkt END AS mkt_source
        , ROW_NUMBER() OVER (PARTITION BY att.store_id, att.click_id ORDER BY att.click_timestamp DESC) AS rownumber

    FROM {{ref('_int_marketing_store_attribution__get_store_partner_info')}} att
	LEFT JOIN affiliate_landing_pages aflp ON att.click_id = aflp.id
	LEFT JOIN {{ref('marketing_inputs_attribution__utm')}} utms ON att.source = utms.source AND att.medium = utms.medium
	LEFT JOIN {{ref('marketing_inputs_attribution__subteam')}} sub ON position(sub.utm_campaign IN att.campaign) > 0	AND  att.source = sub.utm_source AND att.medium = sub.utm_medium	
	LEFT JOIN {{ref('marketing_inputs_attribution__referrer')}} referrer ON position(referrer.referrer IN att.referrer_path) > 0														
	LEFT JOIN {{ref('marketing_inputs_attribution__url')}}  urls ON position(urls.landing_page_path IN att.landing_page_path) > 0	AND position(urls.landing_page_domain IN att.landing_page_domain) > 0
	LEFT JOIN {{ref('marketing_inputs_attribution__insti')}} gii ON position(gii.landing_page_path IN att.landing_page_path) > 0	AND position(gii.landing_page_domain IN att.landing_page_domain) > 0  
	),

final_classification AS (
    SELECT 
        bc.*
        , COALESCE(CASE               
        WHEN bc.utms_source_mkt = 'Performance' AND bc.source = 'google' 
            AND (position('max-perf' IN bc.campaign) > 0) THEN 'Google pMax'            
        WHEN bc.utms_source_mkt = 'Performance' AND bc.source IN ('google','bing') 
            AND (position(bc.sub_utm_campaign IN bc.campaign) > 0) THEN bc.sub_subteam              
        WHEN bc.utms_source_mkt = 'Product Marketing' 
            AND (position(bc.sub_utm_campaign IN bc.campaign) > 0) THEN bc.sub_subteam              
        WHEN bc.source = 'google' AND bc.medium = 'organic' AND bc.referrer_domain = 'gemini.google.com' THEN 'AI'              
        WHEN bc.source = 'chatgpt.com' AND (bc.medium  = '' OR bc.medium  IS NULL) THEN 'AI'
		WHEN bc.mkt_source = 'Organic' and (position('chatgpt' IN bc.source) > 0) THEN 'AI'
		WHEN bc.mkt_source = 'Affiliates' THEN bc.affiliate_type              
        WHEN bc.utms_subteam IS NULL AND bc.mkt_source = bc.sub_team 
            AND (position(bc.sub_utm_campaign IN bc.campaign) > 0) THEN bc.sub_subteam      
        WHEN bc.utms_subteam IS NULL AND bc.mkt_source = bc.urls_team 
            AND (position(bc.urls_landing_page_path IN bc.landing_page_path) > 0)
            AND (position(bc.urls_landing_page_domain IN bc.landing_page_domain) > 0) THEN bc.urls_subteam      
        WHEN bc.utms_subteam IS NULL AND bc.mkt_source = bc.gii_team 
            AND (position(bc.gii_landing_page_path IN bc.landing_page_path) > 0)
            AND (position(bc.gii_landing_page_domain IN bc.landing_page_domain) > 0) THEN bc.gii_subteam
        WHEN bc.utms_subteam IS NULL AND bc.mkt_source = bc.referrer_team 
            AND (position(bc.referrer IN bc.referrer_domain) > 0) THEN bc.referrer_subteam  
        WHEN bc.utms_subteam IS NULL AND bc.mkt_source = bc.partner_team AND bc.flag_partner_exception = 1 AND bc.partner_id IS NOT NULL THEN bc.partner_subteam
		WHEN bc.utms_source_mkt IS NULL THEN bc.mkt_source              
        WHEN bc.utms_subteam IS NOT NULL THEN bc.utms_subteam               
        ELSE bc.mkt_source END, bc.mkt_source) AS mkt_subteam
    FROM base_classification bc
)

SELECT fc.*
FROM final_classification fc
WHERE rownumber = 1