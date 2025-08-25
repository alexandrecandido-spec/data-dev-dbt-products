{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['issue_number', 'issue_country'],
    partition_by = 'created_at',
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with
issues_dates as (
select 
    d.registered_month
    ,i.*
    ,case when registered_month between date_trunc('month', i.created_at) and coalesce(closed_at,date('2100-01-01')) 
        then true 
        else false 
    end as is_ticket_active
from {{ ref('_int_pd_github_issues') }} i
cross join {{ ref('_int_pd_github_dates') }} d
where true
and registered_month between date_trunc('month', i.created_at) and coalesce(closed_at,date('2100-01-01')) 
),
issues as (
    select 
        i.registered_month
        ,i.issue_number as ticket_number
        ,state
        ,created_at
        ,days_open
        ,closed_at
        ,title
        ,labels_tipo
        ,labels_domain
        ,issue_country
        ,i.store_country
        ,url
        ,labels
        ,has_non_tech_enable_tag
        ,has_product_dependent_tag
        ,has_app_improvement_tag
        ,has_new_app_or_integration_tag
        ,count(distinct case when i.store_country = issue_country then i.store_id end) as total_stores
        ,count(distinct case when i.store_country = issue_country and is_dealbreaker then i.store_id end) as dealbreakers
        ,count(distinct case when i.store_country = issue_country and is_high_impact then i.store_id end) as high_impact_stores
        ,max(comments) as stock_comments
        ,sum(gmv_local_currency_monthly) as impacted_gmv_local
        ,sum(gmv_usd_monthly) as impacted_gmv_usd
        --,count(distinct case when is_relevant then i.store_id end) as plus_ones
    from issues_dates i
    left join {{ ref('_int__pd_stores_gmv') }} g
        on  i.store_id = g.store_id
        and i.registered_month = g.registered_month
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
)
select 
    concat(cast(p.ticket_number as string), p.issue_country) as unique_issue_country
    ,p.* 
    ,{% if is_incremental() %}
        coalesce(existing.sys_audit_created_on, current_timestamp) as sys_audit_created_on
    {% else %}
        current_timestamp as sys_audit_created_on
    {% endif %}
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from issues p
{% if is_incremental() %}
left join {{ this }} existing
    on p.ticket_number = existing.ticket_number 
    and p.issue_country = existing.issue_country
{% endif %}