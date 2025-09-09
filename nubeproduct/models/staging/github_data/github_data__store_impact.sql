{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number', 'comment_id'],
        incremental_strategy='merge',
        on_schema_change='fail',
        tags=["product","daily-8am"]
    )
}}

with store_impact as (
    SELECT
        repo_name,
        issue_number,
        comment_id,
        impact,
        ROW_NUMBER() OVER (PARTITION BY repo_name, issue_number, comment_id ORDER BY id ASC) as row_number, -- ordered by id asc to get the first impact (just in case)
        sys_audit_updated_at
    FROM {{ source('stg_github_data', 'store_impact') }}
)
    SELECT
        si.repo_name,
        si.issue_number,
        si.comment_id,
        si.impact,
        current_timestamp AS sys_audit_created_on,
        'data-dev-dbt-products' AS sys_audit_created_by,
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM store_impact si
    WHERE si.row_number = 1 -- we only want one impact per comment_id (just in case)
    AND si.comment_id > 0 -- there are some with comment_id = -1

    {% if is_incremental() %}
    AND
        si.sys_audit_updated_at >= (select coalesce(max(gdsi.sys_audit_updated_on),'1900-01-01') from {{ this }} gdsi)
    {% endif %}