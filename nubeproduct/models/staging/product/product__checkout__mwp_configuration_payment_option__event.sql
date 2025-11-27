{{
    config(
        materialized='incremental',
        unique_key='store_id',
        on_schema_change='fail',
        partition_by= 'year_month_code',
        tags=['product','daily-8am']
    )
}}

WITH source AS (
    select
        year_month_code,
        store_id,
        CAST(sort_type AS STRING) AS sort_type,
        created_at,
        updated_at
    from {{ source('stg_checkout', 'mwp_configuration_payment_option') }}

    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 day' from {{ this }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)
select
year_month_code,
s.store_id,
CAST(s.sort_type AS STRING) AS sort_type,
created_at,
updated_at,
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM source s
LEFT JOIN existing_data e ON s.store_id = e.store_id