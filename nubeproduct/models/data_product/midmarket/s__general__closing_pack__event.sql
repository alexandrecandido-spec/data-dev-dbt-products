{{ config(
    materialized='table',
    tags=['monthly-4th-2pm']
) }}

-- Closing Pack consolidation: only includes closed/completed months
-- Excludes current month to ensure data completeness
-- Runs after key dependencies: midmarket_monthly_business_review (1st at 12pm) 
-- and company_metrics_gmv_and_segments (4th at 10am)

with all_metrics as (
    select * from {{ ref('_int__midmarket__closing_pack_success') }}
        union all
    select * from {{ ref('_int__midmarket__closing_pack_upsell_renewal') }}
        union all
    select * from {{ ref('_int__midmarket__closing_pack_onboarding') }}
        union all
    select * from {{ ref('_int__midmarket__closing_pack_sales') }}
)

select *
from all_metrics
where date_month < date_trunc('month', current_date)