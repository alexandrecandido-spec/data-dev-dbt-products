{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number'],
        on_schema_change='fail',
        tags=["product","daily-4am"]
    )
}}

SELECT
    repo_name,
    issue_number,
    CAST(github_created_at AS DATE) AS created_at,
    CAST(github_closed_at AS DATE) AS closed_at,
    state,
    comments,
    author,
    html_url,
    title
FROM
    {{ source('stg_github_data','issue') }}
