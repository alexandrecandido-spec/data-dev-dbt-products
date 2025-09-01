{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['issue_number', 'repo_name'],
    partition_by = 'created_at',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

with base as (
    select *
    from {{ ref('_int_pd_github_issues_and_problems_errors') }} pf
),
issues_countries as (
    select
        issue_number
        ,concat_ws(';', collect_set(store_country)) as store_countries
    from base
    group by 1
),
aux as (
select distinct
    i.issue_number as ticket_number
    ,repo_name
    ,state
    ,created_at
    ,closed_at
    ,title
    ,url
    ,labels
    ,labels_tipo
    ,labels_domain
    ,labels_country
    ,has_platform_development_tag
    ,is_solved_by_app_br
    ,is_solved_by_app_ar
    ,is_solved_by_app_mx
    ,is_solved_by_app_cl
    ,is_solved_by_app_co
    ,case when repo_name = 'issues' and labels_tipo = 'App' and (labels_domain is null or labels_domain = '') then true 
    else false 
    end as domains_label_missing 
    ,case 
        when is_solved_by_app_br and labels_country not like '%BR%' then true
        when is_solved_by_app_ar and labels_country not like '%AR%' then true
        when is_solved_by_app_mx and labels_country not like '%MX%' then true
        when is_solved_by_app_cl and labels_country not like '%CL%' then true
        when is_solved_by_app_co and labels_country not like '%CO%' then true
        else false
    end as country_tag_missing
    ,case
        when store_countries like '%BR%' and labels_country not like '%BR%' then true
        when store_countries like '%AR%' and labels_country not like '%AR%' then true
        when store_countries like '%MX%' and labels_country not like '%MX%' then true
        when store_countries like '%CL%' and labels_country not like '%CL%' then true
        when store_countries like '%CO%' and labels_country not like '%CO%' then true
    else false
    end as store_country_missin_tag
    ,ic.store_countries
    ,CONCAT_WS( ';',
                case when is_solved_by_app_br and labels_country not like '%BR%' then 'BR' else null end,
                case when is_solved_by_app_ar and labels_country not like '%AR%' then 'AR' else null end,
                case when is_solved_by_app_mx and labels_country not like '%MX%' then 'MX' else null end,
                case when is_solved_by_app_cl and labels_country not like '%CL%' then 'CL' else null end,
                case when is_solved_by_app_co and labels_country not like '%CO%' then 'CO' else null end
                ) as missing_countries_tags
    ,case when (is_solved_by_app_br or is_solved_by_app_ar or is_solved_by_app_mx or is_solved_by_app_cl or is_solved_by_app_co) 
            and not has_platform_development_tag 
            then true 
            else false 
            end as platform_development_tag_missing
    ,case when (state = 'closed' and has_platform_development_tag and repo_name = 'problems') 
                and (labels_country like '%BR%' and not is_solved_by_app_br
                or  labels_country like '%AR%' and not is_solved_by_app_ar
                or  labels_country like '%MX%' and not is_solved_by_app_mx
                or  labels_country like '%CO%' and not is_solved_by_app_co
                or  labels_country like '%CL%' and not is_solved_by_app_cl)
            then true 
            else false 
        end as solved_by_app_tag_missing
    ,concat_ws( ';',
            case when state = 'closed' and has_platform_development_tag and repo_name = 'problems' and labels_country like '%BR%' and not is_solved_by_app_br then 'BR' end ,
            case when state = 'closed' and has_platform_development_tag and repo_name = 'problems' and labels_country like '%AR%' and not is_solved_by_app_br then 'AR' end ,
            case when state = 'closed' and has_platform_development_tag and repo_name = 'problems' and labels_country like '%MX%' and not is_solved_by_app_br then 'MX' end ,
            case when state = 'closed' and has_platform_development_tag and repo_name = 'problems' and labels_country like '%CO%' and not is_solved_by_app_br then 'CO' end ,
            case when state = 'closed' and has_platform_development_tag and repo_name = 'problems' and labels_country like '%CL%' and not is_solved_by_app_br then 'CL' end 
            )
        as solved_by_app_missing_countries
from base i
left join issues_countries ic
    on i.issue_number = ic.issue_number
)
SELECT
    concat(cast(a.ticket_number as string), a.repo_name) as unique_issue_repo
    ,a.*
    ,{% if is_incremental() %}
        coalesce(existing.sys_audit_created_on, current_timestamp) as sys_audit_created_on
    {% else %}
        current_timestamp as sys_audit_created_on
    {% endif %}
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from aux a
{% if is_incremental() %}
left join {{ this }} existing
    on a.ticket_number = existing.ticket_number 
    and a.repo_name = existing.repo_name
{% endif %}
