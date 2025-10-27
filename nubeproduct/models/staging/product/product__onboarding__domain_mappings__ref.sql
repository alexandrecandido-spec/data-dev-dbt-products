{{
    config(
        materialized='incremental',
        unique_key= 'id',
        on_schema_change='fail', 
        tags=['product', 'daily-9am'] 
    )
}}

WITH domain_mappings AS (
    SELECT
        CAST(id AS string) AS id,
        CAST(group_code AS string) AS group_code,
        CAST(type_code AS string) AS type_code
    FROM {{ source('stg_onboarding', 'domain_mappings') }}

    {% if is_incremental() %}
        WHERE dm.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    dm.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM domain_mappings AS dm
LEFT JOIN existing_data e ON dm.id = e.id