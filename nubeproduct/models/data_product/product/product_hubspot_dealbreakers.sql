{{
    config(
        tags=['daily-9am'],
        materialized='incremental',
        unique_key=['dealbreaker_id'],
        on_schema_change='fail'
    )
}}

SELECT
	dealbreaker_id,
    is_archived,
    record_created_at,
    record_updated_at,
    repo_name,
    issue_number,
    store_id,
    company_id,
    impact,
    dealbreaker_start_date,
    dealbreaker_close_date,
    high_start_date,
    high_close_date,
    pipeline,
    pipeline_stage,
    github_title,
    github_status,
    owner_team_id,
    owner_id,
    source_id,
    created_by_user_id,
    updated_by_user_id,
    source_user_id,
    all_owners_ids,
    owner_assigned_at,
    brands,
    record_closed_at,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__hubspot_dealbreakers') }}

{% if is_incremental() %}

WHERE sys_audit_updated_on >= 
(select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )

{% endif %}