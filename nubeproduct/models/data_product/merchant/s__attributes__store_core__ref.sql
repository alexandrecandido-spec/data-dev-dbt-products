{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['store_id'],
    on_schema_change = 'fail',
    tags = ['merchant', 'daily-8am-8pm']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
SELECT 
main_source.store_id
, main_source.created_at
, main_source.domain
, main_source.country_code
, main_source.country_name
, main_source.region_name
, main_source.state_name
, main_source.city_name
, main_source.currency
, main_source.device
, main_source.register_url
, main_source.partner_id
, main_source.partnership_type
, main_source.partner_code
, main_source.vertical_name
, main_source.business_size_name
, main_source.change_timestamp
FROM {{ ref('_int__attributes__store_core') }} main_source
WHERE
    {% if not is_incremental() %}
      main_source.created_at >= DATE '1900-01-01'
    {% endif %}
    {% if is_incremental() %}
      main_source.change_timestamp > ( SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }} )
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
