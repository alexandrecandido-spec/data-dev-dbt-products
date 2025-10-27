{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='sfc_id',
        on_schema_change='fail'
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['sfc_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    cast(sfc.id as bigint) as sfc_id,
    cast(sfc.store_id as integer) as store_id,
    cast(sfc.feature_name as string) as feature_name,
    cast(sfc.enabled as boolean) as feature_enabled,
    cast(sfc.created_at as timestamp) as sfc_created_at,
    cast(sfc.updated_at as timestamp) as sfc_updated_at,
    cast(sfc.year_month_code as int) as sfc_year_month_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_invoices_br', 'store_feature_configuration') }} sfc
LEFT JOIN existing_data e ON cast(sfc.id as bigint) = e.sfc_id

{% if is_incremental() %}
WHERE COALESCE(sfc.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}