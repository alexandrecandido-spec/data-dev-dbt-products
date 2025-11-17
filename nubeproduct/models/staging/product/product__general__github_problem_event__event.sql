{{
    config(
        tags = ['product', 'daily-9am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['id'],
        on_schema_change='fail'
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    source.id,
    source.actor_login,
    source.actor_id,
    source.event,
    source.created_at,
    source.label_name,
    source.number,
    'problems' AS repo_name,
    source.state_reason,
    source.assignee_login,
    source.rename_from,
    source.rename_to,
    source.milestone_title,
    sys_audit_is_deleted,
    sys_audit_deleted_on,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_third_party', 'product_github_problems_events') }} source
LEFT JOIN existing_data e ON source.id = e.id
{% if is_incremental() %}
    WHERE source.sys_audit_updated_on > (SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01 00:00:00'::timestamp) - INTERVAL 1 HOUR FROM {{ this }})
{% endif %}