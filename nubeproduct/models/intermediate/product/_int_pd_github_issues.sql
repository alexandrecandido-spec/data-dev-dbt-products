select distinct
    i.repo_name
    ,i.issue_number
    ,state
    ,created_at
    ,case when state = 'open' then date_diff('day', created_at, current_date) 
        when state = 'closed' then date_diff('day', created_at, closed_at)
    end as days_open
    ,closed_at
    ,title
    ,labels_tipo
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
    ,labels_country
    ,trim(countries) as issue_country
    ,country as store_country
    ,case when i.repo_name = 'problems' then concat('https://github.com/TiendaNube/Problems/issues/',cast(i.issue_number as varchar))
        when i.repo_name = 'issues' then concat('https://github.com/TiendaNube/issues/issues/',cast(i.issue_number as varchar))
    end as url
    ,labels
    ,case when lower(labels) like '%non tech enable%' then true else false end as has_non_tech_enable_tag
    ,case when lower(labels) like '%product dependent%' then true else false end as has_product_dependent_tag
    ,case when lower(labels) like '%app improvement%' then true else false end as has_app_improvement_tag
    ,case when lower(labels) like '%New App or Integration%' then true else false end as has_new_app_or_integration_tag
    ,i.store_id
    --,case when p.is_relevant is null then false else p.is_relevant end as is_relevant
    ,p.comment_date
    ,case when impact = 'dealbreaker' then true else false end as is_dealbreaker
    ,case when impact = 'high' then true else false end as is_high_impact
    ,comments
from {{ ref('product_issues_and_problems_summary') }} i
CROSS JOIN UNNEST(SPLIT(labels_country, ';')) AS t (countries)
/*
left join plus_ones p
    on i.issue_number = p.issue_number
    and i.repo_name = p.repo_name
    and i.store_id = p.store_id
    and i.issue_number = p.issue_number
*/
where true
and i.repo_name = 'issues'
and labels_tipo = 'App'