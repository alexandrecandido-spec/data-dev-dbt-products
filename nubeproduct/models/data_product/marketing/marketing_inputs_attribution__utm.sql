{{ config(
  unique_key=['id'],
  on_schema_change='fail',
  tags=['daily-8am']
) }}

SELECT				
    ai.id
    , ai.input_number
    , ai.input_title
    , ai.input_type
    , ai.state
    , lower(ai.utm_source) AS source				
    , lower(ai.utm_medium) AS medium
    , lower(ai.utm_campaign) AS campaign
    , lower(ai.utm_content) AS content
    , ai.team AS source_mkt				
    , CASE WHEN ai.subteam = 'Ai' THEN 'AI' ELSE ai.subteam END AS subteam
    , ai.created_at
    , ai.updated_at
    , ai.closed_at
    , ai.sys_audit_created_on
    , ai.sys_audit_created_by
    , ai.sys_audit_updated_on
    , ai.sys_audit_updated_by				
FROM {{ ref('marketing_inputs_attribution') }} ai					
--Includes only records associated with UTM campaigns
WHERE ai.input_type = 'UTM'			
AND ai.state = 'open'