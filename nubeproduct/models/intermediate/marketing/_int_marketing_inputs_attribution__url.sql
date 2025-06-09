SELECT				
    ai.landing_page_domain,				
    ai.landing_page_path,				
    ai.team,				
    ai.subteam				
FROM {{ ref('marketing_inputs_attribution') }} ai			
--Includes only records associated with URLs landing pages
WHERE ai.input_type = 'URL'			
AND ai.state = 'open'					