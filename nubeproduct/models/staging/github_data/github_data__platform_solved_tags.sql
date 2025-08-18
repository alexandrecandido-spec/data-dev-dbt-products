{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['issue_number', 'issue_label_name'],
    on_schema_change = 'fail',
    tags = ['daily']
) }}

with issue_labels as (
    select 
        il.issue_number as issue_number,
        il.name as issue_label_name,
        case 
            when il.name = 'Solved by app BR' then 'BR'
            when il.name = 'Solved by app AR' then 'AR'
            when il.name = 'Solved by app CL' then 'CL'
            when il.name = 'Solved by app MX' then 'MX'
            when il.name = 'Solved by app CO' then 'CO'
        end as label_country,
        date(max(ie.github_created_at)) as creation_date
    from {{ source('stg_github_data', 'issue_label') }} il
    left join {{ source('stg_github_data', 'issue_events') }} ie 
        on il.repo_name = ie.repo_name 
        and il.issue_number = ie.issue_number 
        and il.name = ie.content
    where il.name like '%Solved by app%'
    group by il.issue_number, il.name
)
SELECT 
    il.issue_number,
    il.issue_label_name,
    il.label_country,
    il.creation_date,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by 
FROM issue_labels il
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1 
    FROM {{ this }} existing 
    WHERE existing.issue_number = il.issue_number 
    AND existing.issue_label_name = il.issue_label_name
)
{% endif %}