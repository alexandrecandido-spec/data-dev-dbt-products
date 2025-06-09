SELECT	
    referrer		
    , ai.team				
    , ai.subteam				
FROM {{ ref('marketing_inputs_attribution') }} ai					
--Includes only records associated with referrers landing pages
WHERE ai.input_type = 'REFERRER'			
AND ai.state = 'open'