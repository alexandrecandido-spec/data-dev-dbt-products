{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number', 'comment_id'],
        incremental_strategy='merge',
        on_schema_change='fail',
        tags=["product","daily-10am"]
    )
}}

SELECT
    ic.repo_name,
    ic.issue_number,
    ic.id as comment_id,
    ic.author,
    ic.is_relevant,
    CAST(ic.github_created_at as date) as comment_date,
    is.store_id,
    CAST(to_date(github_created_at, 'yyyyMMdd') AS STRING) AS year_month_day_code,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_github_data', 'issue_comment') }} ic
LEFT JOIN {{ source('stg_github_data', 'issue_store') }} is
    ON ic.repo_name = is.repo_name
    AND ic.issue_number = is.issue_number
    AND ic.id = is.comment_id
    
    {% if is_incremental() %}
    WHERE
        sys_audit_updated_at >= (select coalesce(max(j.sys_audit_updated_on),'1900-01-01') from {{ this }} j)
    {% endif %}