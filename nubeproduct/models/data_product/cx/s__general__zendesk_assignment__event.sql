{{
  config(
    materialized='table',
    on_schema_change='fail',
    tags=["cx","daily-7am"]
  )
}}

WITH 
 base AS
(
SELECT
 ticket_id
,event_id
,event_timestamp
,CASE WHEN field_name = 'assignee_id' THEN cast(field_value AS bigint) END AS assignee_change
,CASE WHEN field_name = 'group_id'    THEN cast(field_value AS bigint) END AS group_change
FROM {{ ref('s__general__zendesk_tickets_events__event') }}
WHERE coalesce(field_value,'') <> ''
),
seqs AS 
(
SELECT
 b.*,
sum(CASE WHEN assignee_change is not null THEN 1 ELSE 0 END) over (partition by ticket_id order by event_timestamp, event_id) AS assignee_seq,
sum(CASE WHEN group_change    is not null THEN 1 ELSE 0 END) over (partition by ticket_id order by event_timestamp, event_id) AS group_seq
FROM base b
)
,starts AS 
(
SELECT
ticket_id
,coalesce(max(assignee_change) over (partition by ticket_id, assignee_seq), cast(-1 AS bigint)) AS assignee_id
,coalesce(max(group_change)    over (partition by ticket_id, group_seq   ), cast(-1 AS bigint)) AS group_id_at_start
,event_timestamp AS assignment_start_time
,row_number() over (partition by ticket_id, assignee_seq order by event_timestamp, event_id) AS rnk
FROM seqs
qualify rnk = 1
)
SELECT
 s.ticket_id
,coalesce(s.assignee_id, cast(-1  AS bigint)) AS assignee_id
,coalesce(u.role, 'Not Informed') AS assignment_type
,coalesce(u.name, 'Not Informed') AS guru_name
,s.group_id_at_start AS group_id
,s.assignment_start_time
,coalesce(lead(s.assignment_start_time) over (partition by s.ticket_id order by s.assignment_start_time), timestamp '2100-01-31 00:00:00') AS assignment_end_time
,current_timestamp()     AS sys_audit_created_on
,'data-dev-dbt-products' AS sys_audit_created_by
,current_timestamp()     AS sys_audit_updated_on
,'data-dev-dbt-products' AS sys_audit_updated_by
FROM starts s
left join {{ source('dp_zendesk_support_prod', 'users') }}  u on s.assignee_id = u.id