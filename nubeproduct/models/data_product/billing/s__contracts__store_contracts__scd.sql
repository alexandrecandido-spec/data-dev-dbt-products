{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['hash_key'],
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['hash_key', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
SELECT
main_source.store_id,
main_source.plan_name,
main_source.contract_type,
main_source.created_at_contract,
main_source.start_date,
main_source.end_date,
main_source.sys_audit_updated_on,
main_source.contract_id AS hash_key
FROM {{ ref('_int__billing__store_contracts') }} main_source
WHERE
{% if not is_incremental() %}
  main_source.sys_audit_updated_on >= DATE '1900-01-01'
{% endif %}
{% if is_incremental() %}
  main_source.sys_audit_updated_on > ( SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }} )
{% endif %}
)


SELECT 
sd.* EXCEPT(sd.sys_audit_updated_on)
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by 
FROM source_data sd
LEFT JOIN existing_data e
                          ON sd.hash_key = e.hash_key