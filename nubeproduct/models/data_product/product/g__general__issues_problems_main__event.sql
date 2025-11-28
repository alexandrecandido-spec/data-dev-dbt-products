{{
    config(
        materialized='table',
        unique_key=['issue_number', 'repo_name', 'store_id'],
        partition_by='comment_date',
        tags=["daily-10am"]
    )
}}

select 
    pips.repo_name,
    pips.issue_number,
    pips.created_at,
    pips.closed_at,
    pips.state,
    pips.comments,
    pips.author,
    pips.html_url,
    pips.title,
    pips.pain_point,
    pips.store_id,
    pips.churned_at,
    pips.current_segment,
    pips.country,
    pips.plan,
    pips.store_created_at,
    pips.labels_tipo,
    pips.labels_domain,
    pips.labels_country,
    pips.labels,
    pips.labels_wip,
    pips.labels_quick_fix,
    pips.wip_1_last_updated,
    pips.wip_1_last_deleted,
    pips.wip_2_last_updated,
    pips.wip_2_last_deleted,
    pips.wip_3_last_updated,
    pips.wip_3_last_deleted,
    pips.wip_4_last_updated,
    pips.wip_4_last_deleted,
    pips.milestone_title,
    pips.milestone_created_at,
    pips.status_last_wbr,
    pips.onboarding_ar,
    pips.onboarding_br,
    pips.impact,
    pips.comment_date,
    msi.domain as store_name, 
    wbr.playbook_last_wbr, 
    wbr.date_wbr,
    wbr.status_last_wbr as status_last_wbr_2
from {{ ref('product_issues_and_problems_summary') }} pips
left join {{ ref('company_metrics_merchant_info') }} msi on pips.store_id = msi.store_id
left join (select 
    store_id,
    playbook as playbook_last_wbr,
    status as status_last_wbr,
    date_from as date_wbr
from 
    {{ ref('midmarket_weekly_business_review') }}
where 
    date_from = (select max(date_from) from {{ ref('midmarket_weekly_business_review') }})
    and playbook not in ('Out of portfolio', 'Effective churn')) wbr on pips.store_id = wbr.store_id