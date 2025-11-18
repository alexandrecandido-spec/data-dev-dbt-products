{{
    config(
        materialized='incremental',
        unique_key= 'id',
        on_schema_change='fail',
        tags=['product', 'daily-9am']
    )
}}

WITH source AS (
    SELECT 
        CAST(id AS string) AS id,
        CAST(store_id AS string) AS store_id,
        CAST(status AS string) AS signup_status,
        CAST(created_at AS timestamp) AS created_at,
        CAST(updated_at AS timestamp) AS updated_at
    FROM 
        {{ source('stg_onboarding', 'store_questionnaire_statuses') }}   

    {% if is_incremental() %}
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    a.id,
    a.store_id,
    a.signup_status,
    a.created_at,
    a.updated_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source a
LEFT JOIN existing_data e ON a.id = e.id 
