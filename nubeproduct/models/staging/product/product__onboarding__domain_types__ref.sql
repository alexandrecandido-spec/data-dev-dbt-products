{{
    config(
        materialized='incremental',
        unique_key= 'code',
        on_schema_change='fail', 
        tags=['product', 'daily-9am']
    )
}}

WITH domain_types AS (
    SELECT
        CAST(code AS string) AS code,
        CAST(description AS string) AS description
    FROM {{ source('stg_onboarding', 'domain_types') }}

    {% if is_incremental() %}
        WHERE dm.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['code', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    dt.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM domain_types AS dt
LEFT JOIN existing_data e ON dt.code = e.code