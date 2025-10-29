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
    cast(dba.id as bigint) as dealbreaker_id, -- lo casteo porque viene como string
    dba.archived as is_archived, -- este campo es estático en esta tabla porque en la tabla de origen son todos true, cuando deja de serlo desaparece, pero la estrategia de incrementalidad de airbyte es merge y no elimina registros
    cast(dba.updatedAt as timestamp) as record_updated_at, -- lo casteo porque viene como string
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_hubspot', 'dealbreakers_base_archived') }} dba
LEFT JOIN existing_data e ON cast(dba.id as bigint) = e.dealbreaker_id

{% if is_incremental() %}
WHERE dba._airbyte_extracted_at >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}
