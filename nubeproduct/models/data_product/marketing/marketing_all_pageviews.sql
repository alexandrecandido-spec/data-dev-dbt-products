{{
    config(
        materialized='incremental',
        unique_key=['user_pseudo_id', 'event_timestamp', 'unique_session'],
        partition_by='year_month_code',
        on_schema_change='fail',
        tags=["marketing","daily-8am"]
    )
}}
WITH existing_data AS (
    {{ get_existing_data(this, ['user_pseudo_id', 'event_timestamp', 'unique_session', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by 
FROM {{ ref('_int_marketing_all_pageviews') }} source
LEFT JOIN existing_data e
    ON source.user_pseudo_id = e.user_pseudo_id
    AND source.event_timestamp = e.event_timestamp
    AND source.unique_session = e.unique_session
{% if is_incremental() %}
    WHERE event_date >= (SELECT date_sub(MAX(sys_audit_updated_on), 5) FROM {{ this }})
{% endif %}