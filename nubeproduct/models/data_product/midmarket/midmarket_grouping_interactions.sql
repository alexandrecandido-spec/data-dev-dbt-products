-- Owner: Guille De Felice

{{
    config(
        materialized='incremental',
        unique_key=['date_from', 'store_id', 'periodicity'],
        incremental_strategy='append',
        on_schema_change='fail',
        tags=['midmarket', 'weekly-monday-9am-monthly-1st-12pm']
    )
}}

-- Weekly Dates
with weekly_dates AS (
    SELECT explode(sequence(to_date('2024-01-01'), date_add(trunc(current_date, 'week'), -7), interval 7 days)) AS date_from
),

-- Monthly Dates
monthly_dates AS (
    SELECT explode(
        sequence(
            to_date('2024-01-01'),
            add_months(trunc(current_date, 'month'), -1),
            interval 1 month
        )
    ) AS date_from
)

select 
    wd.date_from,
    ss.store_id,
    'weekly' AS periodicity,
    coalesce(calls, 0) as calls,
    coalesce(emails, 0) as emails,
    coalesce(meetings, 0) as meetings,
    coalesce(tasks, 0) as tasks,
    coalesce(whatsapp, 0) as whatsapp,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by
from 
    {{ ref('midmarket_success_stores') }} ss
    cross join weekly_dates wd
    left join {{ ref('_int_midmarket_wbr_mbr__calls') }} c
        on ss.deal_id = c.deal_id
        and wd.date_from = c.date_from
    left join {{ ref('_int_midmarket_wbr_mbr__emails') }} e
        on ss.deal_id = e.deal_id
        and wd.date_from = e.date_from
    left join {{ ref('_int_midmarket_wbr_mbr__meetings') }} m
        on ss.deal_id = m.deal_id
        and wd.date_from = m.date_from
    left join {{ ref('_int_midmarket_wbr_mbr__tasks') }} t
        on ss.deal_id = t.deal_id
        and wd.date_from = t.date_from
    left join {{ ref('_int_midmarket_wbr_mbr__whatsapp') }} w
        on ss.deal_id = w.deal_id
        and wd.date_from = w.date_from
{% if is_incremental() %}
where
    wd.date_from > (
        SELECT max(date_from) 
        FROM {{ this }} 
        WHERE periodicity = 'weekly'
        )
    AND ss.in_portfolio = true
{% endif %}

union all

select 
    md.date_from,
    ss.store_id,
    'monthly' AS periodicity,
    coalesce(calls, 0) as calls,
    coalesce(emails, 0) as emails,
    coalesce(meetings, 0) as meetings,
    coalesce(tasks, 0) as tasks,
    coalesce(whatsapp, 0) as whatsapp,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by
from 
    {{ ref('midmarket_success_stores') }} ss
    cross join monthly_dates md
    left join {{ ref('_int_midmarket_wbr_mbr__calls') }} c
        on ss.deal_id = c.deal_id
        and md.date_from = c.date_from
    left join {{ ref('_int_midmarket_wbr_mbr__emails') }} e
        on ss.deal_id = e.deal_id
        and md.date_from = e.date_from
    left join {{ ref('_int_midmarket_wbr_mbr__meetings') }} m
        on ss.deal_id = m.deal_id
        and md.date_from = m.date_from
    left join {{ ref('_int_midmarket_wbr_mbr__tasks') }} t
        on ss.deal_id = t.deal_id
        and md.date_from = t.date_from
    left join {{ ref('_int_midmarket_wbr_mbr__whatsapp') }} w
        on ss.deal_id = w.deal_id
        and md.date_from = w.date_from
{% if is_incremental() %}
where
    md.date_from > (
        SELECT max(date_from) 
        FROM {{ this }} 
        WHERE periodicity = 'monthly'
        )
    AND ss.in_portfolio = true
{% endif %}
