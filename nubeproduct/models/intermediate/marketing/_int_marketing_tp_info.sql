with base as (
  select
    concat(source, '-', user_pseudo_id) as id,
    source,
    user_pseudo_id,
    ga_session_id,                          
    event_name,
    event_timestamp,                        
    to_date(from_unixtime(event_timestamp / 1000000)) as event_date,
    device_category
  from {{ ref('marketing__analytics_events') }}
  where event_name in ('Store created','New payment')
),
dedup as ( --deduplication applied due to possible duplicates in GA data -- deduplication needed to clean data sourced from GA4
  select
    id as user_pseudo_id,
    concat(id, '-', cast(ga_session_id as string)) as unique_session,
    event_timestamp,
    source,
    event_name,
    case when event_name = 'Store created' then event_timestamp end as trial_timestamp,
    case when event_name = 'Store created' then to_date(from_unixtime(event_timestamp / 1000000)) end as trial_date,
    case when event_name = 'Store created' then device_category end as trial_device,
    case when event_name = 'New payment' then event_timestamp end as payment_timestamp,
    case when event_name = 'New payment' then to_date(from_unixtime(event_timestamp / 1000000)) end as payment_date,
    case when event_name = 'New payment' then device_category end as payment_device,
    row_number() over (
      partition by concat(id, '-', cast(ga_session_id as string)), user_pseudo_id, event_timestamp
      order by event_timestamp desc
    ) as rn
  from base
)

select *
from dedup
where rn = 1