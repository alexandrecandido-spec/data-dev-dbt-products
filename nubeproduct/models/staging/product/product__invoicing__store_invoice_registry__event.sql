{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='registry_id',
        on_schema_change='fail'
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['registry_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    cast(sir.id as bigint) as registry_id,
    cast(sir.store_id as bigint) as store_id,
    cast(sir.document as string) as document,
    cast(sir.legal_name as string) as legal_name,
    cast(sir.trade_name as string) as trade_name,
    cast(sir.address as string) as address_street,
    cast(sir.number as string) as address_number,
    cast(sir.floor as string) as address_floor,
    cast(sir.locality as string) as address_locality,
    cast(sir.city_code as integer) as city_code,
    cast(sir.city_description as string) as city_name,
    cast(sir.state as string) as state_code,
    cast(sir.zipcode as string) as zipcode,
    cast(sir.phone as string) as phone,
    cast(sir.state_registration as string) as state_registration,
    cast(sir.tax_regime as integer) as tax_regime_code,
    cast(sir.status as string) as registry_status,
    cast(sir.cert_validity_from as timestamp) as cert_validity_from,
    cast(sir.cert_validity_to as timestamp) as cert_validity_to,
    cast(sir.created_at as timestamp) as registry_created_at,
    cast(sir.updated_at as timestamp) as registry_updated_at,
    cast(sir.year_month_code as int) as registry_year_month_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_invoices_br', 'store_invoice_registry') }} sir
LEFT JOIN existing_data e ON cast(sir.id as bigint) = e.registry_id

{% if is_incremental() %}
WHERE COALESCE(sir.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}