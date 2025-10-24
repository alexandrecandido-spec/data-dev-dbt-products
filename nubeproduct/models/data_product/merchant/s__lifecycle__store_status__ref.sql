{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['store_id'],
    on_schema_change = 'fail',
    tags = ['daily-8am-8pm'],
    post_hook=[
            "DELETE FROM {{ this }}
                    WHERE store_id IN (
                        SELECT store_id
                        FROM {{ ref('merchant__attributes__store_info__ref') }}
                        WHERE state = 4 
            )"
            ]
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
SELECT 
main_source.store_id
, main_source.first_payment
, main_source.churned_at
, main_source.first_seller_at
, main_source.new_seller
, main_source.current_plan_id
, main_source.current_plan_name
, main_source.current_plan_type
, main_source.current_segment
, main_source.is_seller
, main_source.max_segment
, main_source.is_store_blocked
, main_source.blocked_reason
, main_source.blocked_at
, main_source.state
, main_source.disabled
, main_source.custom_theme
, main_source.new_payment
, main_source.change_timestamp
FROM {{ ref('_int__lifecycle__store_status') }} main_source
WHERE
main_source.state != 4
{% if not is_incremental() %}
  AND main_source.created_at >= DATE '1900-01-01'
{% endif %}
{% if is_incremental() %}
  AND main_source.change_timestamp > ( SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }} )
{% endif %}
)


SELECT 
sd.* EXCEPT(sd.change_timestamp)
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by 
FROM source_data sd
LEFT JOIN existing_data e
                          ON sd.store_id = e.store_id
