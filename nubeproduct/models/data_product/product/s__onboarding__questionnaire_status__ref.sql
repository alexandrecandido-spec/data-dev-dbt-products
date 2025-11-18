{{
    config(
        materialized='incremental',
        unique_key= 'store_id',
        on_schema_change='fail',
        tags=['daily-9am']
    )
}}

WITH source AS (
    SELECT
        store_id, 
        signup_status,
        time_at_sign_up
    FROM {{ ref('_int__product__onboarding_status') }}   
    {% if is_incremental() %}
    WHERE sys_audit_updated_on >= (select coalesce(DATE_SUB(max(sys_audit_updated_on), 1), '1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    a.store_id,
    a.signup_status,
    a.time_at_sign_up,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source a
LEFT JOIN existing_data e ON a.store_id = e.store_id 