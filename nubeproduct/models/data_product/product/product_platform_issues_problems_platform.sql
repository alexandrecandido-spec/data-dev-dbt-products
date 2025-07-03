{{ config(
    materialized = 'incremental',
    unique_key = 'issue_number',
    partition_by = 'created_at',
    on_schema_change = 'fail',
    tags = ['platform','daily-9am']
) }}

with stores_gmv as (
    SELECT
        s.store_id
        ,s.country
        ,current_segment
        ,first_payment
        ,churned_at
        ,created_at
        ,avg(gmv_local_currency) as avg_gmv_lc_last_3months
        ,avg(total_orders) as avg_orders_last_3months
    from {{ref('moltres__mwp_store_info')}} s
    left join {{ref ('_int__pd_stores_gmv')}} g
        on g.store_id = s.store_id
        and g.country = s.country
    group by 1,2,3,4,5,6
),
labels as (
    select
        issue_number
        ,name as issue_label_name
        ,label_country
        ,label_created_at    
        ,label_updated_at
    from {{ref('pd_issues_problems_tags')}}
),
issues as (
    SELECT
    issue_number
    ,repo_name
    ,state
    ,store_id
    ,country as issue_country
    ,created_at as issue_created_at
    ,closed_at
    ,title
    ,labels_domain
    ,labels
    ,labels_country
    ,has_non_tech_enable_tag
    ,has_product_dependent_tag
    ,is_solved_by_app_country
    from {{ref('_int__pd_github_issues')}}
)
SELECT
    repo_name
    ,issue_number
    ,state
    ,case when is_solved_by_app_country then 'closed' else 'open' end as platform_country_status
    ,case when is_solved_by_app_country then label_created_at end as platform_country_closed_at
    ,created_at
    ,closed_at
    ,title
    ,labels_domain
    ,labels_country
    ,i.country
    ,i.store_id
    ,comments
    ,is_solved_by_app_country
    ,label_created_at
    ,label_updated_at
    ,has_non_tech_enable_tag
    ,has_product_dependent_tag
    ,avg_gmv_lc_last_3months
    ,avg_orders_last_3months
from issues I
left join stores s
    on i.store_id = s.store_id
    and i.country = s.country
left join labels L
    on i.issue_number = l.issue_number
    and i.issue_country = l.label_country