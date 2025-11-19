{{
  config(
    materialized='table',
    on_schema_change='fail',
    tags=["cx","daily-7am"]
  )
}}

with base as 
(
  select
      ticket_id
    , event_id
    , event_timestamp
    , case when field_name = 'assignee_id' then cast(field_value as bigint) end as assignee_change
    , case when field_name = 'group_id'    then cast(field_value as bigint) end as group_change
  from {{ ref('s__general__zendesk_tickets_events__event') }}
  where coalesce(field_value,'') <> ''
)
,seqs as 
(
  select
      b.*
    , sum(case when assignee_change is not null then 1 else 0 end) over (partition by ticket_id order by event_timestamp, event_id) as assignee_seq
    , sum(case when group_change    is not null then 1 else 0 end) over (partition by ticket_id order by event_timestamp, event_id) as group_seq
  from base b
)
,starts as 
(
  select
      ticket_id
    , assignee_seq
    , coalesce(max(assignee_change) over (partition by ticket_id, assignee_seq), cast(-1 as bigint)) as assignee_id
    , coalesce(max(group_change)    over (partition by ticket_id, group_seq   ), cast(-1 as bigint)) as group_id_at_start
    , event_timestamp as assignment_start_time
    , row_number() over (partition by ticket_id, assignee_seq order by event_timestamp, event_id) as rnk
  from seqs
  qualify rnk = 1
)
,bounds as 
(
  select
      ticket_id
    , assignee_seq
    , assignee_id
    , group_id_at_start
    , assignment_start_time
    , lead(assignment_start_time) over (partition by ticket_id order by assignment_start_time, assignee_seq) as assignment_end_time
  from starts
)
,filtered as 
(
  select
      ticket_id
    , assignee_id
    , group_id_at_start as group_id
    , assignment_start_time
    , assignment_end_time
  from bounds
  where assignment_end_time is null or assignment_start_time < assignment_end_time
)
select
    f.ticket_id
  , coalesce(f.assignee_id, cast(-1 as bigint)) as assignee_id
  , coalesce(u.role, 'Not Informed') as assignment_type
  , coalesce(u.name, 'Not Informed') as guru_name
  , f.group_id
  , f.assignment_start_time
  , coalesce(f.assignment_end_time, timestamp '2100-01-31 00:00:00') as assignment_end_time
  , current_timestamp()     as sys_audit_created_on
  , 'data-dev-dbt-products' as sys_audit_created_by
  , current_timestamp()     as sys_audit_updated_on
  , 'data-dev-dbt-products' as sys_audit_updated_by
from filtered f
left join {{ ref('s__general__zendesk_users__ref') }} u on f.assignee_id = u.user_id