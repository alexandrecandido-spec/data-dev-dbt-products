{{
    config(
        materialized='incremental',
        unique_key=['issue_number'],
        incremental_strategy='merge',
        on_schema_change='fail',
        tags=["platform","daily-7am"]
    )
}}

select 
    il.issue_number as issue_number
    ,il.name as issue_label_name
    ,case 
        when il.name = 'Solved by app BR' then 'BR'
        when il.name = 'Solved by app AR' then 'AR'
        when il.name = 'Solved by app CL' then 'CL'
        when il.name = 'Solved by app MX' then 'MX'
        when il.name = 'Solved by app CO' then 'CO'
    end as label_country
    ,date(max(ie.github_created_at)) as creation_date
    ,current_timestamp AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
    ,current_timestamp AS sys_audit_updated_on
    ,'data-dev-dbt-products' AS sys_audit_updated_by
from {{ source('stg_github_data', 'issue_label') }} il
left join {{ source('stg_github_data', 'issue_events') }} ie 
    on il.repo_name = ie.repo_name 
    and il.issue_number = ie.issue_number 
    and il.name = ie.content
where true
and il.name like '%Solved by app%'
{% if is_incremental() %}
and il.sys_audit_updated_on >= (select coalesce(max(il.sys_audit_updated_on),'1900-01-01') from {{ this }} il)
{% endif %}