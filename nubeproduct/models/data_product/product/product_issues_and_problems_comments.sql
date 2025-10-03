{{
    config(
        tags=['daily-9am'],
        materialized='table',
        unique_key=['repo_name', 'issue_number', 'comment_id'],
        on_schema_change='fail'
    )
}}

SELECT
    c.repo_name,
    c.issue_number,
    c.comment_id,
    c.author,
    c.is_relevant,
    c.comment_date,
    c.store_id,
    c.impact,
    CAST(date_format(c.comment_date, 'yyyyMMdd') AS INTEGER) AS year_month_day_code,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__issues_problems_comments_enriched') }} c