{{
    config(
        materialized='table',
        unique_key='id',
        on_schema_change='fail',
        tags=["marketing", "attribution", "daily-4:30am"]
    )
}}

SELECT
    id,
    number AS input_number,
    title AS input_title,
    LOWER(user_login) AS user_create,
    state,
    body,
    assignee,
    comments,
    created_at,
    updated_at,
    closed_at,
    sys_audit_extracted_on,
    COALESCE(sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    current_timestamp AS sys_audit_updated_on,
    COALESCE(sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by, 
    'data-dev-dbt-products' AS sys_audit_updated_by
    FROM {{ source('stg_third_party', 'marketing_github_mkt_attribution') }}