{% set relation_exists = load_relation(this) is not none %}

-- Get the last run date
{% if is_incremental() and relation_exists%}
  {% set last_run_date_query %}
      SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') AS last_run_date
      FROM {{ this }}
  {% endset %}
  {% set results = run_query(last_run_date_query) %}
  {% if execute %}
      {% set last_run_date = results.columns[0].values()[0] %}
  {% else %}
      {% set last_run_date = '1900-01-01' %}
  {% endif %}
{% else %}
  {% set last_run_date = '1900-01-01' %}  
{% endif %}

-- Dynamic construction of optimize command and post hooks commands
{% if is_incremental() and relation_exists%}
    {% set optimize_command %}
        OPTIMIZE {{ this }}
        {% if is_incremental() and relation_exists %}
            WHERE year_month_day_code >= DATE '{{ last_run_date }}'
            ZORDER BY (store_country, store_first_payment)
        {% endif %}
    {% endset %}
{% else %}
   {% set optimize_command = none %}
{% endif %}

{% set post_hooks_commands = [] %}
{% if optimize_command is not none %}
    {% do post_hooks_commands.append(optimize_command) %}
{% endif %}
{% do post_hooks_commands.append("ANALYZE TABLE {{ this }} COMPUTE STATISTICS") %}

-- Dynamic construction of pre_hook
{% if is_incremental() and relation_exists %}
  {% set pre_hook_commands = [
    "DELETE FROM {{ this }} 
        WHERE store_id IN (
            SELECT store_id
            FROM {{ ref('merchant__attributes__store_info__ref') }}
            WHERE state = 4
        )"
  ] %}
{% else %}
  {% set pre_hook_commands = [] %}
{% endif %}


-- Model Config
{{ 
    config(
        materialized = "incremental",
        incremental_strategy = "merge",
        unique_key = "store_id",
        on_schema_change = "fail",
        partition_by = ["year_month_day_code"],
        cluster_by = ["store_country", "store_created_at"],
        tags = ["daily-9am"],
        pre_hook = pre_hook_commands,
        post_hook = post_hooks_commands
    )
}}

-- Model Query
WITH source_data AS (
    SELECT 
    main_source.store_id
    , main_source.store_country
    , main_source.store_created_at
    , main_source.store_first_payment
    , main_source.store_plan_id
    , main_source.deleted_contract
    , date(main_source.store_first_payment) AS year_month_day_code
    FROM {{ ref('_int__lifecycle__first_payment_merchants') }} main_source
    WHERE main_source.first_payment_timestamp >= '{{ last_run_date }}'
),
existing_data AS (

    {% if is_incremental() and relation_exists %}
        SELECT 
            t.store_id,
            t.sys_audit_created_on,
            t.sys_audit_created_by
        FROM {{ this }} t
    {% endif %}
    {% if not is_incremental() %}
        SELECT
            NULL AS store_id,
            NULL AS sys_audit_created_on,
            NULL AS sys_audit_created_by
        WHERE 1 = 0
    {% endif %}
)


SELECT 
sd.*
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by 
FROM source_data sd
LEFT JOIN existing_data e ON sd.store_id = e.store_id
