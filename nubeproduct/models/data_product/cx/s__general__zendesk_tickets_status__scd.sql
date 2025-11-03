{{
  config(
    materialized='table',
    on_schema_change='fail',
    tags=["cx","daily-6am"]
  )
}}

WITH 

 src as 
(
SELECT
ticket_id,
event_timestamp,
event_id,
field_name,
lower(field_value) as status_value
FROM {{ ref('s__general__zendesk_tickets_events__event') }}
WHERE field_name = 'status'
),

ordered as 
(
SELECT
ticket_id,
event_timestamp,
event_id,
status_value,
row_number() over (partition by ticket_id order by event_timestamp, event_id) as version
FROM src
)

SELECT
ticket_id,
status_value,
event_timestamp as valid_from,
coalesce(lead(event_timestamp) over (partition by ticket_id order by event_timestamp, event_id),cast('2100-12-31 00:00:00' as timestamp)) as valid_to,
version,
case when lead(event_timestamp) over (partition by ticket_id order by event_timestamp, event_id) is null then 1 else 0 end as is_current,
current_timestamp()     AS sys_audit_created_on,
'data-dev-dbt-products' AS sys_audit_created_by,
current_timestamp()     AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM ordered