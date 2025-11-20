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
, main_source.business_unit
, main_source.cancellation_reason
, main_source.cancellation_comment
, main_source.cancellation_comment_at
, main_source.is_free_or_paying_merchant
, main_source.is_paying_merchant
, main_source.change_timestamp
FROM {{ ref('_int__lifecycle__store_status') }} main_source
{% if not is_incremental() %}
  WHERE main_source.state != 4
  AND main_source.created_at >= DATE '1900-01-01'
{% endif %}

{% if is_incremental() %}
  -- En modo incremental: solo filas nuevas o con cambios relevantes
  LEFT JOIN {{ this }} AS current_data ON main_source.store_id = current_data.store_id

  {% set monitored_cols = [
            "churned_at",
            "cancellation_reason",
            "cancellation_comment",
            "cancellation_comment_at",
            "business_unit",
            "is_free_or_paying_merchant",
            "is_paying_merchant"
        ] %}

  WHERE main_source.state != 4
  AND (
    current_data.store_id IS NULL
    OR (
        -- cambios en upstream detectados por timestamps
        main_source.change_timestamp > current_data.sys_audit_updated_on
        -- cambios lógicos reversibles
        {%- for col in monitored_cols %}
            OR (main_source.{{ col }} IS DISTINCT FROM current_data.{{ col }})
        {%- endfor %}
    )
  )
{% endif %}
)


SELECT 
sd.* EXCEPT(sd.change_timestamp)
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by 
FROM source_data sd
LEFT JOIN existing_data e ON sd.store_id = e.store_id
