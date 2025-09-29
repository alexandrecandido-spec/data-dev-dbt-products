{{
  config(
    materialized='incremental',
    unique_key='billing_store_id',
    on_schema_change='fail',
    tags=['finance', 'daily-7am']
  )
}}

WITH source_data AS (
    SELECT
        id AS billing_store_id,
        coreid AS store_id,
        countryid AS country_id,
        sys_audit_created_on AS source_sys_audit_created_on,
        sys_audit_created_by AS source_sys_audit_created_by,
        updatedat AS updated_at,
        CAST(date_format(sys_audit_created_on, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM
        {{ source('stg_billing', 'store') }}

    {% if is_incremental() %}
    WHERE updatedat >= (SELECT COALESCE(MAX(updated_at), '1900-01-01') - INTERVAL '1 hour' FROM {{ this }})
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['billing_store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    s.billing_store_id,
    s.store_id,
    s.country_id,
    s.year_month_day_code,
    s.updated_at,
    COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    source_data s
LEFT JOIN
    existing_data e ON s.billing_store_id = e.billing_store_id