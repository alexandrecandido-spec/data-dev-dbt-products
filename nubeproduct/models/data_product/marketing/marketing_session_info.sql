{{ config(
    materialized='incremental',
    unique_key=['unique_session'],
    incremental_strategy='merge',
    on_schema_change='fail',
    partition_by='year_month_code',
    tags=['marketing','daily-8am']
) }}
WITH existing_data AS (
    {{ get_existing_data(this, ['unique_session', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by 
FROM {{ ref('_int_marketing_session_info') }} source
LEFT JOIN existing_data e
    ON source.unique_session = e.unique_session
{% if is_incremental() %}
    WHERE source.start_session_date >= (SELECT date_sub(MAX(sys_audit_updated_on), 5) FROM {{ this }})
    or source.end_session_date >= (SELECT date_sub(MAX(sys_audit_updated_on), 5) FROM {{ this }})
{% endif %}