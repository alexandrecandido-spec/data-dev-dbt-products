{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='table',
        unique_key='dealbreaker_id',
        on_schema_change='fail'
    )
}}

SELECT
    cast(dba.id as bigint) as dealbreaker_id, -- lo casteo porque viene como string
    cast(dba.updatedAt as timestamp) as record_updated_at, -- lo casteo porque viene como string
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_hubspot', 'dealbreakers_base_association') }} dba