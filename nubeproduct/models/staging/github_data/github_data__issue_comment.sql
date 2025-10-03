{{
    config(
        materialized='table',
        unique_key=['repo_name', 'issue_number', 'comment_id'],
        on_schema_change='fail',
        tags=["product","daily-8am"]
    )
}}

SELECT
    repo_name,
    issue_number,
    id AS comment_id,
    author,
    is_relevant,
    CAST(github_created_at as date) as comment_date,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_github_data', 'issue_comment') }} ic