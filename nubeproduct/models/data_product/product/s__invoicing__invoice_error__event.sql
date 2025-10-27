{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['request_id', 'error_group', 'error_code', 'error_detail'],
        on_schema_change = 'fail',
        tags = ['daily-8am']
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['request_id', 'error_group', 'error_code', 'error_detail', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    ie.request_id,
    ie.store_id,
    ie.error_group,
    ie.error_code,
    ie.error_type,
    ie.error_detail,
    ie.error_normalized,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int__product__invoicing__invoice_error_input') }} ie
LEFT JOIN existing_data e
    ON ie.request_id = e.request_id
    AND ie.error_group = e.error_group
    AND ie.error_code = e.error_code
    AND ie.error_detail = e.error_detail

{% if is_incremental() %}
WHERE COALESCE(ie.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}