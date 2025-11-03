WITH 
 parsed AS 
(
SELECT
 ticket_id
,id as audit_id
,author_id
,date_format(to_timestamp(created_at, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"), 'yyyy-MM-dd HH:mm:ss') as created_at
,from_json(events,'array<struct<id:bigint,field_name:string,value:string,macro_id:string>>') AS events_json
,date(_airbyte_extracted_at) as airbyte_extracted_at
FROM {{ source("int_zendesk_support_prod", "ticket_audits") }}
)
SELECT
 a.ticket_id
,a.audit_id
,a.author_id
,e.macro_id
,a.created_at
,a.airbyte_extracted_at
FROM parsed a
LATERAL VIEW explode(events_json) exploded AS e