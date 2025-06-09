SELECT				
    ai.landing_page_domain				
    , ai.landing_page_path				
    , ai.team				
    , ai.subteam				
FROM {{ ref('marketing_inputs_attribution') }} ai					
--Includes only records associated with INSTI landing pages
WHERE ai.input_type = 'INSTI'			
AND ai.state = 'open'	