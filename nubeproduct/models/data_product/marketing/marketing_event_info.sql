{{ config(
    materialized='incremental',
    unique_key=['user_pseudo_id', 'unique_session', 'event_timestamp', 'event_name'],
    incremental_strategy='merge',
    on_schema_change='fail',
    partition_by='year_month_code',
    tags=['marketing','daily-8am']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['user_pseudo_id', 'unique_session', 'event_timestamp', 'event_name', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.*, 
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_marketing_event_info') }} source
LEFT JOIN existing_data e
    ON source.user_pseudo_id = e.user_pseudo_id
    AND source.unique_session = e.unique_session
    AND source.event_timestamp = e.event_timestamp
    AND source.event_name = e.event_name
{% if is_incremental() %}
    WHERE source.event_date >= (SELECT date_sub(MAX(sys_audit_updated_on), 5) FROM {{ this }})
{% endif %}