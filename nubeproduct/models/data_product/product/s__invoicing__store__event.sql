{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['store_id'],
        on_schema_change = 'fail',
        tags = ['daily-8am']
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    si.store_id,
    si.tag,
    si.tag_created_date,
    si.registry_created_date,
    si.registry_updated_date,
    si.feature_name,
    si.feature_enabled,
    si.feature_activation_date,
    si.domain,
    si.legal_name,
    si.trade_name,
    si.plan_group,
    si.store_state,
    si.current_segment,
    si.country,
    si.address_city,
    si.address_state,
    si.tax_regime_code,
    si.tax_regime_name,
    si.registry_status,
    si.cert_valid,
    si.days_to_cert_expire,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int__product__invoicing__store_input') }} si
LEFT JOIN existing_data e
    ON si.store_id = e.store_id

{% if is_incremental() %}
WHERE COALESCE(si.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}