SELECT				
    ai.utm_source			
    , ai.utm_medium
    , ai.utm_campaign							
    , ai.utm_content				
    , ai.team				
    , ai.subteam				
FROM {{ ref('marketing_inputs_attribution') }} ai					
--Includes only records associated with subteams
WHERE ai.input_type = 'SUBTEAM_MKT'			
AND ai.state = 'open'