{{
    config(
        materialized='incremental',
        unique_key= ['store_id', 'onboarding_type'],
        on_schema_change='fail',
        tags=['onboarding', 'daily-8am']
    )
}}

WITH source AS (
    SELECT 
        CAST(store_id AS string) AS store_id,
        CAST(COALESCE(onboarding_type, 'online_store') AS string) AS onboarding_type,
        CAST(created_at AS timestamp) AS created_at
    FROM 
        {{ source('stg_onboarding', 'onboarding_store_preference_types') }}   

    {% if is_incremental() %}
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'onboarding_type', 'created_at', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    a.store_id,
    a.onboarding_type,
    a.created_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source a
LEFT JOIN existing_data e ON a.store_id = e.store_id and a.onboarding_type = e.onboarding_type
