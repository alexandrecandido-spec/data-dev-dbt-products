{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='dealbreaker_id',
        on_schema_change='fail'
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['dealbreaker_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    cast(dca.dealbreaker_id as bigint) as dealbreaker_id,
    dca.type as association_type,
    cast(dca.company_id as bigint) as company_id,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_hubspot', 'dealbreakers_companies_associations') }} dca
LEFT JOIN existing_data e ON cast(dca.dealbreaker_id as bigint) = e.dealbreaker_id

{% if is_incremental() %}
WHERE dca._airbyte_extracted_at >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}