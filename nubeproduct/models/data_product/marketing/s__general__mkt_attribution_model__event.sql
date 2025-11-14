{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['click_id', 'store_id'],
    partition_by = 'year_month_day_code',
    on_schema_change = 'fail',
    tags = ['daily-10am'],
    post_hook=[
            "DELETE FROM {{ this }}
                    WHERE store_id NOT IN (
                        SELECT store_id
                        FROM {{ ref('moltres__mwp_store_info') }}
            )"
            ]
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['click_id', 'store_id', 'input_sources', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
  main_source.store_id
, main_source.click_order
, main_source.click_qty
, main_source.click_id
, main_source.click_timestamp
, main_source.source
, main_source.medium
, main_source.campaign
, main_source.content
, main_source.referrer_domain
, main_source.referrer_path
, main_source.landing_page_domain
, main_source.landing_page_path
, main_source.attribution_source
, main_source.country_code
, main_source.year_month_day_code
, main_source.register_url
, main_source.mkt_source
, main_source.mkt_subteam
--, main_source.channel --- pendiente para agregar cuando se incorpore en inputs_utms
--, main_source.subchannel    --- pendiente para agregar cuando se incorpore en inputs_utms
--, main_source.page_groups --- pendiente para agregar (lógica según landings)
--, main_source.subpage_groups --- pendiente para agregar (lógica según landings)
, main_source.trials_last_click
, main_source.trials_first_click
, main_source.trials_mean_click
, main_source.input_sources
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_marketing_attribution_model__get_final_classification') }} main_source
LEFT JOIN existing_data e
                          ON main_source.click_id = e.click_id AND main_source.store_id = e.store_id
WHERE
    {% if not is_incremental() %}
    --  main_source.created_at >= DATE '2010-01-01'
    main_source.created_at >= DATE '2025-01-01'
    {% endif %}
    {% if is_incremental() %}
    (
      main_source.change_timestamp_incremental > (
        SELECT COALESCE(MAX(sys_audit_created_on) - INTERVAL 1 DAY, DATE '1900-01-01')
        FROM {{ this }}
      )
      -- updates due to inputs: new or deleted
      OR {{ input_changed('utm') }}
      OR {{ input_changed('subteam') }}
      OR {{ input_changed('referrer') }}
      OR {{ input_changed('url') }}
      OR {{ input_changed('insti') }}
      OR {{ input_changed('partner_fraud') }}
      OR {{ input_changed('affiliate_classification') }}
      OR {{ input_changed('partner_exception') }}
    )
    {% endif %}