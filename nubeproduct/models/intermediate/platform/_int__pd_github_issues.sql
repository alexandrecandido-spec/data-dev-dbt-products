with issues as (
select
    repo_name,
    issue_number,
    state,
    created_at,
    closed_at,
    title,
    labels_domain,
    labels_country,
    TRIM(countries) AS country,
    labels,
    store_id,
    comments,
    case when lower(labels) like '%solved by app br%' then true else false end as is_solved_by_app_br,
    case when lower(labels) like '%solved by app ar%' then true else false end as is_solved_by_app_ar,
    case when lower(labels) like '%solved by app cl%' then true else false end as is_solved_by_app_cl,
    case when lower(labels) like '%solved by app co%' then true else false end as is_solved_by_app_co,
    case when lower(labels) like '%solved by app mx%' then true else false end as is_solved_by_app_mx,
    case when lower(labels) like '%non-tech-enable%' then true else false end as has_non_tech_enable_tag,
    case when lower(labels) like '%product-dependent%' then true else false end as has_product_dependent_tag
from {{ ref('product_issues_and_problems_summary') }}
CROSS JOIN UNNEST(SPLIT(labels_country, ';')) AS t (countries)
where labels_tipo = 'App'
)
select 
    i.issue_number
    ,i.repo_name
    ,i.state
    ,i.store_id
    ,i.country as issue_country
    ,i.created_at as issue_created_at
    ,i.closed_at
    ,i.title
    ,i.labels_domain
    ,i.labels
    ,i.labels_country
    ,has_non_tech_enable_tag
    ,has_product_dependent_tag
    ,case 
        when i.country = 'AR' and is_solved_by_app_ar then true
        when i.country = 'BR' and is_solved_by_app_br then true
        when i.country = 'CL' and is_solved_by_app_cl then true
        when i.country = 'CO' and is_solved_by_app_co then true
        when i.country = 'MX' and is_solved_by_app_mx then true
        else false
    end as is_solved_by_app_country
from issues i