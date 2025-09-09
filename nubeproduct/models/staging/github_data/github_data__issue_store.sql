{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number', 'comment_id'],
        incremental_strategy='merge',
        on_schema_change='fail',
        tags=["product","daily-8am"]
    )
}}

with issue_store as (
    SELECT
        repo_name,
        issue_number,
        comment_id,
        store_id,
        ROW_NUMBER() OVER (PARTITION BY repo_name, issue_number, comment_id ORDER BY id ASC) as row_number, -- ordered by id asc to get the first store_id (proxy)
        sys_audit_updated_at
    FROM {{ source('stg_github_data', 'issue_store') }}
)
    SELECT
        is.repo_name,
        is.issue_number,
        is.comment_id,
        is.store_id,
        current_timestamp AS sys_audit_created_on,
        'data-dev-dbt-products' AS sys_audit_created_by,
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM issue_store is
    WHERE is.row_number = 1 -- we only want one store_id per comment_id
    
    {% if is_incremental() %}
    AND
        is.sys_audit_updated_at >= (select coalesce(max(gdis.sys_audit_updated_on),'1900-01-01') from {{ this }} gdis)
    {% endif %}