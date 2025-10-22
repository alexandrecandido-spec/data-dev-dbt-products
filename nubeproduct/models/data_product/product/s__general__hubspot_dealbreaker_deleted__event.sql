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

    archived.dealbreaker_id,
    archived.is_archived,
    d.record_created_at, -- si aparece null es porque se creó y eliminó el registro en el mismo día, antes de alguna ingesta de airbyte
    GREATEST(
        COALESCE(archived.record_updated_at, CAST('1900-01-01' AS TIMESTAMP)), 
        COALESCE(d.record_updated_at, CAST('1900-01-01' AS TIMESTAMP))) 
    AS record_updated_at,
    d.repo_name,
    d.issue_number,
    c.store_id,
    c.company_id,
    d.impact,
    d.dealbreaker_start_date,
    d.dealbreaker_close_date,
    d.high_start_date,
    d.high_close_date,
    d.pipeline,
    d.pipeline_stage,
    d.github_title,
    d.github_status,
    d.owner_team_id,
    d.owner_id,
    d.source_id,
    d.created_by_user_id,
    d.updated_by_user_id,
    d.source_user_id,
    d.all_owners_ids,
    d.owner_assigned_at,
    d.brands,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('product__general__hubspot_dealbreaker_archived__event') }} archived
LEFT JOIN {{ ref('product__general__hubspot_dealbreaker_current__snapshot_daily') }} current
    ON archived.dealbreaker_id = current.dealbreaker_id
LEFT JOIN {{ ref('product__general__hubspot_dealbreaker__event') }} d
    ON archived.dealbreaker_id = d.dealbreaker_id
LEFT JOIN {{ ref('product__general__hubspot_dealbreaker_company__link') }} link
    ON archived.dealbreaker_id = link.dealbreaker_id
LEFT JOIN {{ ref('product__general__hubspot_company__event') }} c
    ON link.company_id = c.company_id
LEFT JOIN existing_data e
    ON archived.dealbreaker_id = e.dealbreaker_id

WHERE current.dealbreaker_id IS NULL

{% if is_incremental() %}
AND GREATEST(
    COALESCE(archived.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
    COALESCE(d.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
    COALESCE(link.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
    COALESCE(c.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), CAST('1900-01-01' AS TIMESTAMP)) FROM {{ this }}
)
{% endif %}