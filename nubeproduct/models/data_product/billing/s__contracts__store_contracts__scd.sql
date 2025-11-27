-- Get the relation exists
{% set relation_exists = load_relation(this) is not none %}

-- Get the last run date
{% set last_updated_cutoff %}
  {% if is_incremental() %}
    (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }})
  {% else %}
    DATE '1900-01-01'
  {% endif %}
{% endset %}

-- Dynamic construction of optimize command and post hooks commands
{% if is_incremental() and relation_exists%}
    {% set optimize_command %}
        OPTIMIZE {{ this }}
        {% if is_incremental() and relation_exists %}
            WHERE sys_audit_updated_on >= DATE '{{ last_updated_cutoff }}'
            ZORDER BY (store_id, is_current)
        {% endif %}
    {% endset %}
{% else %}
   {% set optimize_command = "OPTIMIZE {{ this }} ZORDER BY (store_id, is_current)" %}
{% endif %}

{% set post_hooks_commands = [] %}
{% if optimize_command is not none %}
    {% do post_hooks_commands.append(optimize_command) %}
{% endif %}
{% do post_hooks_commands.append("ANALYZE TABLE {{ this }} COMPUTE STATISTICS") %}

{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['hash_key'],
    partition_by = ['created_at_contract'],
    cluster_by = ['store_id'],
    on_schema_change = 'fail',
    tags = ['daily-8am'],
    post_hook = post_hooks_commands
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['hash_key', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

-- Merchants that have at least one deleted contract with a new update
merchants_with_deleted_contracts AS (
  SELECT DISTINCT store_id
  FROM {{ ref('_int__billing__store_contracts') }}
  WHERE
    deleted_contract = true
    AND sys_audit_updated_on > {{ last_updated_cutoff }}
),

-- Merchants that have at least one contract with a new update
merchants_with_general_updates AS (
  SELECT DISTINCT store_id
  FROM {{ ref('_int__billing__store_contracts') }}
  WHERE sys_audit_updated_on > {{ last_updated_cutoff }}
),

-- Union of both types of merchants
affected_stores AS (
  SELECT store_id FROM merchants_with_general_updates
  UNION
  SELECT store_id FROM merchants_with_deleted_contracts
),

source_data AS (
SELECT
main_source.store_id,
main_source.plan_id,
main_source.plan_name,
main_source.contract_type,
main_source.deleted_contract,
main_source.deleted_at_contract,
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
main_source.merchant_has_deleted_contract,
main_source.contract_id AS hash_key
FROM {{ ref('_int__billing__store_contracts') }} main_source
WHERE
{% if is_incremental() %}
  (
  -- New or updated contracts by stores
   main_source.store_id IN (SELECT store_id FROM affected_stores)
  )
{% else %}
  1 = 1
{% endif %}
)

SELECT 
sd.* EXCEPT(sd.sys_audit_updated_on)
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by 
FROM source_data sd
LEFT JOIN existing_data e ON sd.hash_key = e.hash_key