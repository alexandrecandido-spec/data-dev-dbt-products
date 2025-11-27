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
WHERE field_name IN ('satisfaction_score','assignee_id','group_id') 
AND   COALESCE(field_value, '') <> ''
)
,pivoted AS 
(
SELECT
 ticket_id
,event_timestamp
,event_id
,CASE WHEN field_name = 'satisfaction_score' THEN field_value END AS sfs_raw
,CASE WHEN field_name = 'assignee_id'        THEN field_value END AS asg_raw
,CASE WHEN field_name = 'group_id'           THEN field_value END AS grp_raw
FROM events
)
,filled_structs AS 
(
SELECT
 ticket_id
,event_timestamp
,event_id
,sfs_raw
,MAX(CASE WHEN sfs_raw IS NOT NULL THEN named_struct('t', event_timestamp, 'e', event_id, 'v', sfs_raw) END) OVER w AS sfs_s
,MAX(CASE WHEN asg_raw IS NOT NULL THEN named_struct('t', event_timestamp, 'e', event_id, 'v', asg_raw) END) OVER w AS asg_s
,MAX(CASE WHEN grp_raw IS NOT NULL THEN named_struct('t', event_timestamp, 'e', event_id, 'v', grp_raw) END) OVER w AS grp_s
FROM pivoted
WINDOW w AS (PARTITION BY ticket_id ORDER BY event_timestamp, event_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
)
SELECT
 ticket_id
,event_timestamp
,event_id
,sfs_s.v AS satisfaction_score
,COALESCE(CAST(asg_s.v AS BIGINT),-1) AS assignee_id
,COALESCE(CAST(grp_s.v AS BIGINT),-1) AS group_id
,current_timestamp()     AS sys_audit_created_on
,'data-dev-dbt-products' AS sys_audit_created_by
,current_timestamp()     AS sys_audit_updated_on
,'data-dev-dbt-products' AS sys_audit_updated_by
FROM filled_structs
WHERE sfs_raw IS NOT NULL