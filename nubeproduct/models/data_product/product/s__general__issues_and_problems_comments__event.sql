{{
    config(
        materialized='table',
        unique_key=['issue_number', 'repo_name', 'comment_id', 'store_id'],
        partition_by='comment_date',
        tags=["daily-10am"]
    )
}}

with base_issues as(
select distinct
repo_name,
issue_number,
title,
store_id,
country,
created_at,
closed_at,
case when pips.status_last_wbr = true then 1 else 0 end as mm,
case when pips.country = 'AR' and  pips.status_last_wbr = true then 1 else 0 end as mm_ar,
case when pips.country = 'BR' and  pips.status_last_wbr = true then 1 else 0 end as mm_br,
status_last_wbr,
impact,
onboarding_ar,
onboarding_br,
--snapshots,
1 as all,
labels_tipo,
labels_domain,
labels_country,
labels
from {{ ref('product_issues_and_problems_summary') }} pips
)
select distinct 
base_data.repo_name,
base_data.issue_number,
base_data.title,
ic.id as comment_id, 
ic.author,
ic.is_relevant,
bi.impact,
p.store_id, 
cast(ic.github_created_at as date) as comment_date,
base_data.created_at as open_date,
base_data.closed_at as closed_date,
base_data.labels_tipo, 
base_data.labels_domain, 
base_data.labels_country, 
base_data.labels,
cmm.country_code as store_country,
cmm.current_segment_name as store_segment,
bi.onboarding_ar,
bi.onboarding_br,
bi.mm_ar,
bi.mm_br,
current_timestamp AS sys_audit_created_on, 
'data-dev-dbt-products' AS sys_audit_created_by, 
current_timestamp AS sys_audit_updated_on, 
'data-dev-dbt-products' AS sys_audit_updated_by
from (select distinct repo_name, issue_number, title, created_at, closed_at, labels_tipo, labels_domain, labels_country, labels 
    from base_issues) base_data
left join {{ ref('s__general__github_issue_comment__event') }} ic  on base_data.repo_name = ic.repo_name and base_data.issue_number = ic.issue_number  
left join {{ ref('s__general__github_issue_store__link') }} p on base_data.repo_name = p.repo_name and base_data.issue_number = p.issue_number and ic.id = p.comment_id --and p.comment_id is not null
left join base_issues bi on ic.repo_name = bi.repo_name and bi.issue_number = ic.issue_number and p.store_id = bi.store_id
left join {{ ref('company_metrics_merchant_info') }}  cmm on p.store_id = cmm.store_id