{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['registered_month', 'issue_number', 'platform_country_state', 'country'],
    partition_by = 'created_at',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

with 
problems_dates as (
    select 
        d.registered_month
        ,p.*
    from {{ ref('_int__pd_github_problems') }} p
    cross join {{ ref('_int_pd_github_dates') }} d
),
base as (
    select 
    pf.registered_month
    ,issue_number
    ,title
    ,repo_name
    ,state
    ,labels_tipo
    ,labels
    ,case 
        when state = 'closed' and is_solved_by_app_country then 'Solved' 
        when state = 'open' and is_solved_by_app_country then 'Solved'
        when state = 'closed' and not is_solved_by_app_country then 'Ended'
        when state = 'open' and labels_tipo = 'App' then 'Platform Open' 
        else 'Open Problems'
        end as platform_country_state
    ,created_at
    ,ticket_closed_at
    ,label_closed_date
    ,case when pf.registered_month between date_trunc('month', created_at) and min_close_date 
            or (pf.registered_month = min_close_date and pf.registered_month = created_at)
        then true 
        else false 
        end as is_ticket_active
    ,case when min_close_date > current_date then null else min_close_date end as min_close_date
    ,trim(both ';' FROM concat_ws(';',labels_domain,
            CASE 
                WHEN labels LIKE '%Dropshipping App%' 
                 AND (labels_domain IS NULL OR labels_domain NOT LIKE '%Dropshipping App%') 
                THEN 'Dropshipping App' END,
            CASE 
                WHEN labels LIKE '%Sales Channels App%' 
                 AND (labels_domain IS NULL OR labels_domain NOT LIKE '%Sales Channels App%') 
                THEN 'Sales Channels App'END
            )) 
        AS labels_domain
    ,case when state = 'closed' and is_solved_by_app_country then country_fix
        when state = 'open' and is_solved_by_app_country then country_fix
        when state = 'open' and not is_solved_by_app_country then store_country
        when state = 'closed' and not is_solved_by_app_country then store_country
        else country_fix end as country
    ,is_solved_by_app_country
    ,has_non_tech_enable_tag
    ,has_product_dependent_tag
    ,max(comments) as max_comments
    ,count(distinct case when store_country = country_fix then pf.store_id end) as impacted_stores
    ,count(distinct case when store_country = country_fix and impact = 'dealbreaker' then pf.store_id end) as dealbreakers
    ,count(distinct case when store_country = country_fix and impact = 'high' then pf.store_id end) as high_impacted_stores
    ,sum(case when store_country = country_fix then avg_gmv_lc_last_3months end) / 3 as impacted_gmv
    ,sum(case when store_country = country_fix then gmv_usd_monthly end) / 3 as impacted_gmv_usd
    from problems_dates pf
    left join {{ ref('_int__pd_stores_gmv') }} g
        on pf.store_id = g.store_id
    and (case when is_solved_by_app_country then
            g.registered_month between add_months(date_trunc('month', min_close_date), -3) and date_trunc('month', min_close_date)
        else g.registered_month >= add_months(date_trunc('month', current_date()), -3)
        end)
    where true
        and pf.registered_month between date_trunc('month', created_at) and coalesce(min_close_date, date('2100-01-01')) 
        or (pf.registered_month = min_close_date and pf.registered_month = created_at)
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
)
select
    concat(cast(p.registered_month as string) , cast(p.issue_number as string), p.country) as unique_issue_country
    ,p.registered_month
    ,p.issue_number
    ,p.title
    ,p.repo_name
    ,p.state
    ,p.labels_tipo
    ,p.labels
    ,p.platform_country_state
    ,p.created_at
    ,p.ticket_closed_at
    ,case when p.platform_country_state = 'Open Problems' then null else p.label_closed_date end as label_closed_date
    ,case when p.platform_country_state = 'Open Problems' then null else p.min_close_date end as min_close_date
    ,p.labels_domain
    ,p.country
    ,p.is_solved_by_app_country
    ,p.has_non_tech_enable_tag
    ,p.has_product_dependent_tag
    ,p.max_comments
    ,p.impacted_stores
    ,p.dealbreakers
    ,p.high_impacted_stores
    ,p.impacted_gmv
    ,p.impacted_gmv_usd
    ,{% if is_incremental() %}
        coalesce(existing.sys_audit_created_on, current_timestamp) as sys_audit_created_on
    {% else %}
        current_timestamp as sys_audit_created_on
    {% endif %}
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from base p
{% if is_incremental() %}
left join {{ this }} existing
    on p.registered_month = existing.registered_month
    and p.issue_number = existing.issue_number 
    and p.platform_country_state = existing.platform_country_state 
    and p.country = existing.country
{% endif %}