-- Owner: Guille De Felice

{{
    config(
        materialized='table', 
        on_schema_change='fail',
        tags=['weekly-monday-930am-monthly-1st-11am']
    )
}}

select
    *,
    'new_warning' as warning_event
from
    {{ ref('g__success__new_warnings__agg_snapshot_weekly_monthly') }}

union all

select
    *,
    'outgoing_warning' as warning_event
from
    {{ ref('g__success__outgoing_warnings__agg_snapshot_weekly_monthly') }}