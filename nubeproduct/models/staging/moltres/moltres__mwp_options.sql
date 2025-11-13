{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}

WITH options AS (
    SELECT 
    year_month_code,
    id,
    store_id,
    option_name,
    option_value,
    created_at,
    updated_at
    FROM {{ source('stg_moltres', 'mwp_options') }} 
    {% if is_incremental() %}
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    o.year_month_code,
    o.id,
    o.store_id,
    o.option_name,
    o.option_value,
    o.created_at,
    o.updated_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM options AS o
LEFT JOIN existing_data e ON o.id =e.id