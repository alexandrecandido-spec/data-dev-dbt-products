{{
    config(
        tags=['daily-9am'],
        materialized='table',
        unique_key=['repo_name', 'issue_number', 'comment_id'],
        on_schema_change='fail'
    )
}}

SELECT
    repo_name,
    issue_number,
    comment_id,
    author,
    is_relevant,
    comment_date,
    store_id,
    impact,
    CAST(date_format(comment_date, 'yyyyMMdd') AS INTEGER) AS year_month_day_code,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__issues_problems_comments_enriched') }}