{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['dealbreaker_id'],
        on_schema_change = 'fail',
        tags = ['daily-8am']
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['dealbreaker_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    base.dealbreaker_id,
    base.is_archived,
    base.record_created_at,
    base.record_updated_at,
    base.repo_name,
    base.issue_number,
    base.store_id,
    base.company_id,
    base.impact,
    base.dealbreaker_start_date,
    base.dealbreaker_close_date,
    base.high_start_date,
    base.high_close_date,
    base.pipeline,
    base.pipeline_stage,
    base.github_title,
    base.github_status,
    base.owner_team_id,
    base.owner_id,
    base.source_id,
    base.created_by_user_id,
    base.updated_by_user_id,
    base.source_user_id,
    base.all_owners_ids,
    base.owner_assigned_at,
    base.brands,
    
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int_product__hubspot_dealbreaker_current') }} base
LEFT JOIN existing_data e 
    ON base.dealbreaker_id = e.dealbreaker_id

{% if is_incremental() %}
WHERE base.sys_audit_updated_on >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}
