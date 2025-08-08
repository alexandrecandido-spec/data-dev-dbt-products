{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['click_id', 'store_id'],
    partition_by = 'year_month_day_code',
    on_schema_change = 'fail',
    tags = ['daily-10am']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['click_id', 'store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
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
, main_source.country
, main_source.year_month_day_code
, main_source.created_at
, main_source.first_payment
, main_source.churned_at
, main_source.first_seller_at
, main_source.device
, main_source.register_url
, main_source.partner_id
, main_source.partner_code
, main_source.partnership_type
, main_source.new_payment_probability
, main_source.prod_cutoff
, main_source.blocked_fraud_tag
, main_source.flag_affiliate
, main_source.affiliate_type
, main_source.mkt_source
, main_source.mkt_subteam
, main_source.trials_last_click
, main_source.trials_first_click
, main_source.trials_mean_click
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_marketing_store_attribution__get_mkt_source_classification') }} main_source
LEFT JOIN existing_data e
                          ON main_source.click_id = e.click_id AND main_source.store_id = e.store_id
WHERE
    {% if not is_incremental() %}
      main_source.created_at >= DATE '2010-01-01'
    {% endif %}
    {% if is_incremental() %}
      main_source.change_timestamp > (
        SELECT COALESCE(MAX(sys_audit_created_on) - INTERVAL 1 DAY, DATE '1900-01-01')
        FROM {{ this }}
      )
    {% endif %}