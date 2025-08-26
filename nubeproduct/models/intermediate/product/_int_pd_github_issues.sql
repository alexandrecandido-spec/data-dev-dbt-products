with base as (
    select *
    from {{ ref('product_issues_and_problems_summary') }} i
    where repo_name = 'issues'
      and labels_tipo = 'App'
),
exploded as (
    select
        b.*,
        trim('AR') as issue_country
    from base b
    where b.labels_country like '%AR%'
    UNION ALL
    select
        b.*,
        trim('BR') as issue_country
    from base b
    where b.labels_country like '%BR%'
    UNION ALL
    select
        b.*,
        trim('MX') as issue_country
    from base b
    where b.labels_country like '%MX%'
    UNION ALL
    select
        b.*,
        trim('CO') as issue_country
    from base b
    where b.labels_country like '%CO%'
    UNION ALL
    select
        b.*,
        trim('CL') as issue_country
    from base b
    where b.labels_country like '%CL%'
)
select distinct
    repo_name,
    issue_number,
    state,
    created_at,
    case when state = 'open' then datediff(current_date, cast(created_at as date)) 
         when state = 'closed' then datediff(cast(closed_at as date), cast(created_at as date))
    end as days_open,
    closed_at,
    title,
    trim(both ';' FROM concat_ws(';',labels_domain,
        case when labels like '%Dropshipping App%' 
              and (labels_domain is null or labels_domain not like '%Dropshipping App%') 
             then 'Dropshipping App' end,
        case when labels like '%Sales Channels App%' 
              and (labels_domain is null or labels_domain not like '%Sales Channels App%') 
             then 'Sales Channels App' end
    )) as labels_domain,
    labels_country,
    labels_tipo,
    issue_country,
    country as store_country,
    case when repo_name = 'problems' then concat('https://github.com/TiendaNube/Problems/issues/',cast(issue_number as string))
         when repo_name = 'issues' then concat('https://github.com/TiendaNube/issues/issues/',cast(issue_number as string))
    end as url,
    labels,
    case when lower(labels) like '%non tech enable%' then true else false end as has_non_tech_enable_tag,
    case when lower(labels) like '%product dependent%' then true else false end as has_product_dependent_tag,
    case when lower(labels) like '%app improvement%' then true else false end as has_app_improvement_tag,
    case when lower(labels) like '%new app or integration%' then true else false end as has_new_app_or_integration_tag,
    store_id,
    case when impact = 'dealbreaker' then true else false end as is_dealbreaker,
    case when impact = 'high' then true else false end as is_high_impact,
    comments
from exploded

/*
Datos faltantes para agregar
    --,case when p.is_relevant is null then false else p.is_relevant end as is_relevant
    --,i.comment_date
    left join plus_ones p
    on i.issue_number = p.issue_number
    and i.repo_name = p.repo_name
    and i.store_id = p.store_id
    and i.issue_number = p.issue_number
*/