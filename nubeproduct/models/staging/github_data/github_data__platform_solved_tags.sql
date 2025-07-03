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
    issue_number
    ,name as issue_label_name
    ,case 
        when name = 'Solved by app BR' then 'BR'
        when name = 'Solved by app AR' then 'AR'
        when name = 'Solved by app CL' then 'CL'
        when name = 'Solved by app MX' then 'MX'
        when name = 'Solved by app CO' then 'CO'
    end as label_country
    ,sys_admin_created_at as label_created_at    
    ,sys_audit_updated_at as label_updated_at
from {{ source('stg_github_data', 'issue_label') }} l
where true
and name like '%Solved by app%'
{% if is_incremental() %}
and sys_audit_updated_at >= (select coalesce(max(j.sys_audit_updated_on),'1900-01-01') from {{ this }} j)
{% endif %}