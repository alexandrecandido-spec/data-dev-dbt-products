{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['hash_key'],
    partition_by = ['year_month_code'],
    cluster_by = ['store_id'],
    on_schema_change = 'fail',
    tags = ['daily-8am'],
    post_hook = "OPTIMIZE {{ this }} ZORDER BY (store_id, is_current)"
) }}

{% set last_updated_cutoff %}
  {% if is_incremental() %}
    (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }})
  {% else %}
    DATE '1900-01-01'
  {% endif %}
{% endset %}


WITH existing_data AS (
  {{ get_existing_data(this, ['hash_key', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
SELECT
main_source.store_id,
main_source.plan_id,
main_source.plan_name,
main_source.contract_type,
main_source.contracts_total,
main_source.created_at_contract,
main_source.start_date_contract, 
main_source.end_date_contract,
main_source.sys_audit_updated_on,
main_source.change_reason,
main_source.is_current,
main_source.contract_order,
main_source.contracts_qty,
main_source.tag AS merchant_tag,
main_source.merchant_has_anomaly,
main_source.contract_id AS hash_key
FROM {{ ref('_int__billing__store_contracts') }} main_source
WHERE sys_audit_updated_on > {{ last_updated_cutoff }}
)

SELECT 
sd.* EXCEPT(sd.sys_audit_updated_on)
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by 
, TRUNC(start_date_contract, 'MM') AS year_month_code
FROM source_data sd
LEFT JOIN existing_data e
                          ON sd.hash_key = e.hash_key