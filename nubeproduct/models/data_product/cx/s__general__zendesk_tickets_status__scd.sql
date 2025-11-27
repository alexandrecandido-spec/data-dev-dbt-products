{{
  config(
    materialized='table',
    on_schema_change='fail',
    tags=["daily-6am"]
  )
}}

WITH 
 events AS 
(
SELECT
 ticket_id
,event_timestamp
,event_id
,field_name
,field_value
FROM  {{ ref('s__general__zendesk_tickets_events__event') }}
WHERE field_name IN ('status','assignee_id','group_id') 
AND   COALESCE(field_value, '') <> ''
)
,pivoted AS 
(
SELECT
 ticket_id
,event_timestamp
,event_id
,CASE WHEN field_name = 'status'      THEN field_value END AS status_raw
,CASE WHEN field_name = 'assignee_id' THEN field_value END AS assignee_raw
,CASE WHEN field_name = 'group_id'    THEN field_value END AS group_raw
FROM events
)
,filled_structs AS 
(
SELECT
 ticket_id
,event_timestamp
,event_id
,status_raw
,MAX(CASE WHEN status_raw   IS NOT NULL THEN named_struct('t', event_timestamp, 'e', event_id, 'v', status_raw)   END) OVER w AS status_s
,MAX(CASE WHEN assignee_raw IS NOT NULL THEN named_struct('t', event_timestamp, 'e', event_id, 'v', assignee_raw) END) OVER w AS assignee_s
,MAX(CASE WHEN group_raw    IS NOT NULL THEN named_struct('t', event_timestamp, 'e', event_id, 'v', group_raw)    END) OVER w AS group_s
FROM pivoted
WINDOW w AS (PARTITION BY ticket_id ORDER BY event_timestamp, event_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
)
,src AS
(
SELECT
 ticket_id
,event_timestamp
,event_id
,status_s.v AS status
,CAST(assignee_s.v AS BIGINT) AS assignee_id
,CAST(group_s.v    AS BIGINT) AS group_id
FROM filled_structs
WHERE status_raw IS NOT NULL
)
,ordered as 
(
SELECT
 ticket_id
,event_timestamp
,event_id
,status
,assignee_id
,group_id
,row_number() over (partition by ticket_id order by event_timestamp, event_id) as version
FROM src
)
SELECT
 ticket_id
,event_id
,coalesce(assignee_id,-1) as assignee_id
,coalesce(group_id,-1) as group_id
,status
,event_timestamp as valid_from
,coalesce(lead(event_timestamp) over (partition by ticket_id order by event_timestamp, event_id),cast('2100-12-31 00:00:00' as timestamp)) as valid_to
,version
,case when lead(event_timestamp) over (partition by ticket_id order by event_timestamp, event_id) is null then 1 else 0 end as is_current
,current_timestamp()     AS sys_audit_created_on
,'data-dev-dbt-products' AS sys_audit_created_by
,current_timestamp()     AS sys_audit_updated_on
,'data-dev-dbt-products' AS sys_audit_updated_by
FROM ordered