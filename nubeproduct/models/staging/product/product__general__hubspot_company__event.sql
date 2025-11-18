{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='company_id',
        on_schema_change='fail'
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['company_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    cast(c.company_id as bigint) as company_id,
    cast(c.store_id as integer) as store_id,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_hubspot', 'companies') }} c
LEFT JOIN existing_data e ON cast(c.company_id as bigint) = e.company_id

WHERE c._airbyte_raw_id <> 'df0aa495-11a2-4e0a-93bd-4b0257f24ab4' -- descarto un registro viejo que se ingestó mal, para poder detectar futuros nulos

{% if is_incremental() %}
AND c._airbyte_extracted_at >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}
