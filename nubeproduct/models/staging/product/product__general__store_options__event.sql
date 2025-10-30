{{
    config(
        materialized='table',
        unique_key='id',
        on_schema_change='fail',
        partition_by= 'year_month_day_code',
        tags=['product','daily-1am']
    )
}}

WITH source AS (
select
year_month_code,
id,
store_id,
option_name,
option_value,
created_at,
updated_at,
CONCAT(CAST(DATE(updated_at) AS STRING),'-',CAST(store_id AS STRING)) option_date_store_id,
CAST(date_format(updated_at, 'yyyyMMdd') AS INT) AS year_month_day_code
from {{ source('stg_moltres', 'mwp_options') }}

    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 hour' from {{ this }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)
select
year_month_code,
source.id,
store_id,
option_name,
option_value,
created_at,
updated_at,
option_date_store_id,
year_month_day_code,
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.id = e.id