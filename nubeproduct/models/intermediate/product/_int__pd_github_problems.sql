with
issues as (
    select distinct
        repo_name
        ,i.issue_number
        ,state
        ,created_at
        ,closed_at
        ,title
        ,labels_tipo
        ,labels_domain
        ,labels_country
        ,country as store_country
        ,labels
        ,store_id
        ,impact
        ,comments
        ,case when lower(labels) like '%solved by app br%' then true else false end as is_solved_by_app_br
        ,case when lower(labels) like '%solved by app ar%' then true else false end as is_solved_by_app_ar
        ,case when lower(labels) like '%solved by app cl%' then true else false end as is_solved_by_app_cl
        ,case when lower(labels) like '%solved by app co%' then true else false end as is_solved_by_app_co
        ,case when lower(labels) like '%solved by app mx%' then true else false end as is_solved_by_app_mx
        ,case when lower(labels) like '%non tech enable%' then true else false end as has_non_tech_enable_tag
        ,case when lower(labels) like '%product dependent%' then true else false end as has_product_dependent_tag
        ,case when lower(labels) like '%app improvement%' then true else false end as has_app_improvement_tag
        ,case when lower(labels) like '%new app or integration%' then true else false end as has_new_app_or_integration_tag
    from {{ ref('product_issues_and_problems_summary') }} i
    where true
),
solving_countries as (
    select issue_number, 'AR' as country from issues where is_solved_by_app_ar and repo_name = 'problems'
    union
    select issue_number, 'BR' as country from issues where is_solved_by_app_br and repo_name = 'problems'
    union
    select issue_number, 'MX' as country from issues where is_solved_by_app_mx and repo_name = 'problems'
    union 
    select issue_number, 'CO' as country from issues where is_solved_by_app_co and repo_name = 'problems'
    union 
    select issue_number, 'CL' as country from issues where is_solved_by_app_cl and repo_name = 'problems'
),
problems_final as (
    select distinct
    i.issue_number
    ,repo_name
    ,title
    ,state
    ,i.created_at
    ,closed_at
    ,labels_tipo
    ,labels_domain
    ,i.store_country
    ,s.country as solving_country
    ,case 
        when store_country = 'AR' and is_solved_by_app_ar then true
        when store_country = 'BR' and is_solved_by_app_br then true
        when store_country = 'MX' and is_solved_by_app_mx then true
        when store_country = 'CO' and is_solved_by_app_co then true
        when store_country = 'CL' and is_solved_by_app_cl then true
        else false
        end as is_solved_by_app_country
    ,is_solved_by_app_ar
    ,is_solved_by_app_br
    ,is_solved_by_app_co
    ,is_solved_by_app_cl
    ,is_solved_by_app_mx
    ,has_non_tech_enable_tag
    ,has_product_dependent_tag
    ,comments
    ,store_id
    ,impact
    from issues i
    left join solving_countries s
        on i.issue_number = s.issue_number
    where true
    and repo_name = 'problems'
    or (is_solved_by_app_ar 
        or is_solved_by_app_br 
        or is_solved_by_app_co 
        or is_solved_by_app_cl 
        or is_solved_by_app_mx)
)
select distinct 
    p.issue_number
    ,title
    ,store_id
    ,store_country
    ,impact
    ,comments
    ,repo_name
    ,state
    ,p.created_at 
    ,closed_at as ticket_closed_at
    ,t.creation_date as label_closed_date
    ,least(
        coalesce(closed_at, date('2100-01-01')),
        coalesce(t.creation_date, date('2100-01-01'))
        ) as min_close_date
    ,case when state = 'closed' or is_solved_by_app_country then
        case when store_country = solving_country then store_country
        else solving_country
        end 
        when state = 'open' and not is_solved_by_app_country then store_country end
        as country_fix
    ,is_solved_by_app_ar
    ,is_solved_by_app_br
    ,is_solved_by_app_mx
    ,is_solved_by_app_cl
    ,is_solved_by_app_co
    ,has_non_tech_enable_tag
    ,has_product_dependent_tag
    ,labels_tipo
    ,labels_domain
from problems_final p
left join {{ ref('github_data__platform_solved_tags') }} t
    on p.issue_number = t.issue_number
    and (case when store_country = solving_country then store_country
        else solving_country
        end) = t.label_country
where true 