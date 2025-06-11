{{
    config(
        materialized='incremental',
        unique_key=['isocode','processed_at'],
        incremental_strategy='merge',
        on_schema_change='fail',
        tags=["daily-2pm"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['isocode', 'processed_at', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM 
    {{ ref('_int_finance_exchange_rate__window_currencies') }} source
LEFT JOIN existing_data e ON source.isocode = e.isocode and source.processed_at = e.processed_at
WHERE
    {% if not is_incremental() %}
        source.processed_at > '2018-01-01'
    {% endif %}
    {% if is_incremental() %}
        source.processed_at > (SELECT MAX(processed_at) AS max_processed_at
                            FROM {{ source('dp_finance', 'finance_exchange_rate') }})
    {% endif %}