{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='table',
        unique_key='dealbreaker_id',
        on_schema_change='fail'
    )
}}

SELECT
    cast(dca.dealbreaker_id as bigint) as dealbreaker_id,
    dca.type as association_type,
    cast(dca.company_id as bigint) as company_id,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_hubspot', 'dealbreakers_companies_associations') }} dca