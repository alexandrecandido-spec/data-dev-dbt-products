{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['repo_name','store_id','issue_number'],
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}

select distinct
    i.repo_name,
    i.issue_number,
    i.created_at,
    i.closed_at,
    i.state,
    i.comments,
    i.author,
    i.html_url,
    i.title,
    v.store_id,
    s.churned_at,
    s.current_segment,
    s.country,
    s.plan,
    cast(s.created_at as date) as store_created_at,
    l.labels_tipo,
    l.labels_domain,
    l.labels_country,
    l.labels,
    l.labels_wip,
    labels_quick_fix,
    w1.wip_last_updated as wip_1_last_updated,
    w1.wip_last_deleted as wip_1_last_deleted,
    w2.wip_last_updated as wip_2_last_updated,
    w2.wip_last_deleted as wip_2_last_deleted,
    w3.wip_last_updated as wip_3_last_updated,
    w3.wip_last_deleted as wip_3_last_deleted,
    w4.wip_last_updated as wip_4_last_updated,
    w4.wip_last_deleted as wip_4_last_deleted,
    mi.milestone_title,
    mi.milestone_created_at,
    case when onb.country = 'AR' then 1 end as onboarding_ar,
    case when onb.country = 'BR' then 1 end as onboarding_br,
    db.comment_date,
    db.impact,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from {{ ref('_int_github_data_issues_problems_main') }} i
    left join {{ ref('github_data__merchant_impact') }} v
        on i.repo_name = v.repo_name 
            and i.issue_number = v.issue_number

    left join {{ ref('moltres__mwp_store_info') }} s
        on s.store_id = v.store_id

    left join {{ ref('github_data__issue_labels') }} l
        on i.repo_name = l.repo_name 
            and i.issue_number = l.issue_number 

    left join {{ ref('_int_github_data_issues_problems_hubspot_onboarding') }} onb 
        on onb.store_id = v.store_id

    left join {{ ref('github_data__issue_wip_labels') }} w1
        on i.repo_name = w1.repo_name 
		    and i.issue_number = w1.issue_number   
            and w1.wip_label = '1 - WIP - Identificando problema'

    left join {{ ref('github_data__issue_wip_labels') }} w2
        on i.repo_name = w1.repo_name 
		    and i.issue_number = w1.issue_number   
            and w1.wip_label = '2 - WIP - Entendiendo solucion'

    left join {{ ref('github_data__issue_wip_labels') }} w3
        on i.repo_name = w1.repo_name 
		    and i.issue_number = w1.issue_number   
            and w1.wip_label = '3 - WIP - Ejecutando solucion'

    left join {{ ref('github_data__issue_wip_labels') }} w4
        on i.repo_name = w1.repo_name 
		    and i.issue_number = w1.issue_number   
            and w1.wip_label = '4 - WIP - Monitoreando solucion'

    left join {{ ref('_int_github_data_issues_problems_milestones') }} mi
        on i.repo_name = mi.repo_name 
			and i.issue_number = mi.issue_number 

    left join {{ ref('_int_github_data_issues_problems_comments') }} db
        on i.repo_name = db.repo_name 
		    and i.issue_number = db.issue_number 
		    and v.store_id = db.store_id

        {% if is_incremental() %}
    WHERE 
        l.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or v.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or i.sys_audit_updated_at >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or s.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or onb.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or w1.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or w2.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or w3.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or w4.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or mi.sys_audit_updated_at >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or db.sys_audit_updated_at >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
    {% endif %}