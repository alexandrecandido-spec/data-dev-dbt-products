{{ config(
    materialized = 'incremental',
    incremental_strategy='merge',
    unique_key = ['issue_number', 'platform_country_state','country'],
    partition_by = 'created_at',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

with problems as (
select 
    issue_number
    ,title
    ,repo_name
    ,state
    ,labels_tipo
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
    ,case when min_close_date > current_date then null else min_close_date end as min_close_date
    ,labels_domain
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
from {{ ref('_int__pd_github_problems') }} pf
left join {{ ref('_int__pd_stores_gmv') }} g
    on pf.store_id = g.store_id
    and (case when is_solved_by_app_country then
            registered_month between date_add(MONTH, -3, date_trunc('month', min_close_date)) and date_trunc('month', min_close_date)
        else registered_month >= date_add(MONTH, -3, date_trunc('month', current_date)) 
        end)
where true
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
)
select 
    p.* 
    ,{% if is_incremental() %}
        COALESCE(existing.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
    {% else %}
        current_timestamp AS sys_audit_created_on
    {% endif %}
    ,'data-dev-dbt-products' AS sys_audit_created_by
    ,current_timestamp AS sys_audit_updated_on
    ,'data-dev-dbt-products' AS sys_audit_updated_by
from problems p
{% if is_incremental() %}
left join {{ this }} existing
    on p.issue_number = existing.issue_number 
    and p.platform_country_state = existing.platform_country_state 
    and p.country = existing.country
{% endif %}