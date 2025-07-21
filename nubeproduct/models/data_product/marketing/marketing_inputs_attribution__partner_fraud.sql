{{ config(
  unique_key=['id'],
  on_schema_change='fail',
  tags=['daily-9am']
) }}

SELECT				
    ai.id
    , ai.input_number
    , ai.input_title
    , ai.input_type
    , ai.state
    , ai.partner_code
    , ai.fraude
    , ai.created_at
    , ai.updated_at
    , ai.closed_at
    , ai.sys_audit_created_on
    , ai.sys_audit_created_by
    , ai.sys_audit_updated_on
    , ai.sys_audit_updated_by			
FROM {{ ref('marketing_inputs_attribution') }} ai	
--Includes only records associated with partners tagged as fraud			
WHERE ai.input_type = 'PARTNER_FRAUD'	
AND ai.state = 'open'	
