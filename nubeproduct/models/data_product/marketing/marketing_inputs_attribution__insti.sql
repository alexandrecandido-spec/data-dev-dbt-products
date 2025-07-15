{{ config(
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "daily-8am"]
) }}

SELECT				
    ai.id
    , ai.input_number
    , ai.input_title
    , ai.input_type
    , ai.state
    , ai.landing_page_domain			
    , ai.landing_page_path				
    , ai.team
    , ai.subteam
    , ai.created_at
    , ai.updated_at
    , ai.closed_at
    , ai.sys_audit_created_on
    , ai.sys_audit_created_by
    , ai.sys_audit_updated_on
    , ai.sys_audit_updated_by				
FROM {{ ref('marketing_inputs_attribution') }} ai					
--Includes only records associated with INSTI landing pages
WHERE ai.input_type = 'INSTI'			
AND ai.state = 'open'