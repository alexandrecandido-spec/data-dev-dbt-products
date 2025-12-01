{{ config(
    materialized='table',
    tags=['weekly-monday-1030am']
) }}

-- Weekly Closing Pack consolidation: only includes closed/completed weeks
-- Excludes current week to ensure data completeness
-- Runs after key dependencies: midmarket_weekly_business_review 
-- and company_metrics_weekly_snapshot_gmv

with all_metrics as (
    select * from {{ ref('_int__midmarket__closing_pack_weekly_success') }}
        union all
    select * from {{ ref('_int__midmarket__closing_pack_weekly_upsell_renewal') }}
        union all
    select * from {{ ref('_int__midmarket__closing_pack_weekly_onboarding') }}
        union all
    select * from {{ ref('_int__midmarket__closing_pack_weekly_sales') }}
)

select *
from all_metrics
where date_week < date_trunc('week', current_date)
    and date_week >= '2023-01-01'

