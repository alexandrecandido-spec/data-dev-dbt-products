SELECT				
    lower(ai.utm_source) AS source				
    , lower(ai.utm_medium) AS medium				
    , ai.team AS source_mkt				
    , ai.subteam				
FROM {{ ref('marketing_inputs_attribution') }} ai					
--Includes only records associated with UTM campaigns
WHERE ai.input_type = 'UTM'			
AND ai.state = 'open'
