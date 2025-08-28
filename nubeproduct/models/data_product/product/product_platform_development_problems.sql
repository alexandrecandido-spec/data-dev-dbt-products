{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['issue_number', 'platform_country_state', 'country'],
    partition_by = 'created_at',
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with base as (
    select
        pf.*,
        case
            when pf.country_fix = 'AR' then coalesce(pf.is_solved_by_app_ar, false)
            when pf.country_fix = 'BR' then coalesce(pf.is_solved_by_app_br, false)
            when pf.country_fix = 'CL' then coalesce(pf.is_solved_by_app_cl, false)
            when pf.country_fix = 'CO' then coalesce(pf.is_solved_by_app_co, false)
            when pf.country_fix = 'MX' then coalesce(pf.is_solved_by_app_mx, false)
            else false
        end as is_solved_by_app_country
    from {{ ref('_int__pd_github_problems') }} pf
),
problems as (
    select 
        pf.issue_number
        ,pf.title
        ,pf.repo_name
        ,pf.state
        ,pf.labels_tipo
        ,case 
            when pf.state = 'closed' and pf.is_solved_by_app_country then 'Solved' 
            when pf.state = 'open'  and pf.is_solved_by_app_country then 'Solved'
            when pf.state = 'closed' and not pf.is_solved_by_app_country then 'Ended'
            when pf.state = 'open' and pf.labels_tipo = 'App' then 'Platform Open' 
            else 'Open Problems'
         end as platform_country_state
        ,pf.created_at
        ,pf.ticket_closed_at
        ,pf.label_closed_date
        ,case when pf.min_close_date > current_date then null else pf.min_close_date end as min_close_date
        ,pf.labels_domain
        ,case when pf.state = 'closed' and pf.is_solved_by_app_country then pf.country_fix
              when pf.state = 'open'  and pf.is_solved_by_app_country then pf.country_fix
              when pf.state = 'open'  and not pf.is_solved_by_app_country then pf.store_country
              when pf.state = 'closed' and not pf.is_solved_by_app_country then pf.store_country
              else pf.country_fix end as country
        ,pf.is_solved_by_app_country
        ,pf.has_non_tech_enable_tag
        ,pf.has_product_dependent_tag
        ,max(pf.comments) as max_comments
        ,count(distinct case when pf.store_country = pf.country_fix then pf.store_id end) as impacted_stores
        ,count(distinct case when pf.store_country = pf.country_fix and pf.impact = 'dealbreaker' then pf.store_id end) as dealbreakers
        ,count(distinct case when pf.store_country = pf.country_fix and pf.impact = 'high' then pf.store_id end) as high_impacted_stores
        ,sum(case when pf.store_country = pf.country_fix then g.avg_gmv_lc_last_3months end) / 3 as impacted_gmv
        ,sum(case when pf.store_country = pf.country_fix then g.gmv_usd_monthly end) / 3 as impacted_gmv_usd
    from base pf
    left join {{ ref('_int__pd_stores_gmv') }} g
        on pf.store_id = g.store_id
        and (
            case when pf.is_solved_by_app_country then
                registered_month between date_add(MONTH, -3, date_trunc('month', pf.min_close_date)) and date_trunc('month', pf.min_close_date)
            else 
                registered_month >= date_add(MONTH, -3, date_trunc('month', current_date))
            end
        )
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
)
select 
    concat(cast(p.issue_number as string), p.country) as unique_issue_country
    ,p.* 
    ,{% if is_incremental() %}
        coalesce(existing.sys_audit_created_on, current_timestamp) as sys_audit_created_on
    {% else %}
        current_timestamp as sys_audit_created_on
    {% endif %}
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from problems p
{% if is_incremental() %}
left join {{ this }} existing
    on p.issue_number = existing.issue_number 
    and p.platform_country_state = existing.platform_country_state 
    and p.country = existing.country
{% endif %}
