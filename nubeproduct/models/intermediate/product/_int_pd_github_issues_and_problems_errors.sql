    select distinct
        repo_name
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
        ,case when i.repo_name = 'problems' then concat('https://github.com/TiendaNube/Problems/issues/',cast(i.issue_number as varchar))
            when i.repo_name = 'issues' then concat('https://github.com/TiendaNube/issues/issues/',cast(i.issue_number as varchar))
        end as url
        ,labels_country
        ,country as store_country
        ,labels
        ,case when lower(labels) like '%solved by app br%' then true else false end as is_solved_by_app_br
        ,case when lower(labels) like '%solved by app ar%' then true else false end as is_solved_by_app_ar
        ,case when lower(labels) like '%solved by app cl%' then true else false end as is_solved_by_app_cl
        ,case when lower(labels) like '%solved by app co%' then true else false end as is_solved_by_app_co
        ,case when lower(labels) like '%solved by app mx%' then true else false end as is_solved_by_app_mx
        ,case when lower(labels) like '%platform development%' then true else false end as has_platform_development_tag
    from {{ ref('product_issues_and_problems_summary') }} i
    where true
    and labels_tipo = 'App'