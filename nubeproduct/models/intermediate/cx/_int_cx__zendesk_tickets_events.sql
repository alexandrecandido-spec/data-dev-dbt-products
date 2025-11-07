WITH 
 parsed AS 
(
SELECT
 ticket_id
,date_format(to_timestamp(created_at, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"), 'yyyy-MM-dd HH:mm:ss') as event_timestamp
,from_json(events,'array<struct<id:bigint,field_name:string,value:string>>') AS events_json
,date(_airbyte_extracted_at) as airbyte_extracted_at
FROM {{ source("int_zendesk_support_prod", "ticket_audits") }}
)
,exploded AS
(
SELECT
 a.ticket_id
,a.event_timestamp
,e.id AS event_id
,e.field_name
,e.value as field_value
,a.airbyte_extracted_at
FROM parsed a
LATERAL VIEW explode(events_json) exploded AS e
)
SELECT
 ticket_id
,event_timestamp
,event_id
,field_name
,field_value
,airbyte_extracted_at
FROM exploded
WHERE field_name in ('status','group_id','assignee_id','satisfaction_score')