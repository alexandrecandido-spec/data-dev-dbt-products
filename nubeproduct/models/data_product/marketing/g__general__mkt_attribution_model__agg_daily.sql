{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = [
      'store_id', 'source', 'medium', 'campaign', 'content',
      'referrer_domain', 'referrer_path', 'landing_page_domain', 'landing_page_path', 'register_url'
      ],
    on_schema_change = 'fail',
    tags = ['daily-10am'],
    post_hook = ["DELETE FROM {{ this }} WHERE store_id NOT IN (SELECT store_id FROM {{ ref('moltres__mwp_store_info') }})"]
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['store_id', 'input_sources', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
  main_source.store_id
, main_source.source
, main_source.medium
, main_source.campaign
, main_source.content
, main_source.referrer_domain
, main_source.referrer_path
, main_source.landing_page_domain
, main_source.landing_page_path
, main_source.register_url
, main_source.partner_id
--, flag_quality_lead -- nueva
--, flat_potential_seller -- nueva
, main_source.mkt_source
, main_source.mkt_subteam
--, main_source.channel
--, main_source.subchannel
--, page_groups -- nueva
--, subpage_groups -- nueva
, main_source.trials_last_click
, main_source.trials_first_click
, main_source.trials_mean_click
--, main_source.trials_partner_click -- nueva
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_marketing_store_attribution__get_store_partner_info') }} main_source
LEFT JOIN existing_data e
                          ON main_source.store_id = e.store_id
                          and main_source.source = e.source
                          and main_source.medium = e.medium
                          and main_source.campaign = e.campaign
                          and main_source.content = e.content
                          and main_source.referrer_domain = e.referrer_domain
                          and main_source.referrer_path = e.referrer_path
                          and main_source.landing_page_domain = e.landing_page_domain
                          and main_source.landing_page_path = e.landing_page_path
                          and main_source.register_url = e.register_url
WHERE
    {% if not is_incremental() %}
      main_source.created_at >= DATE '2010-01-01'
    {% endif %}
    {% if is_incremental() %}
    (
      main_source.change_timestamp_incremental > (
        SELECT COALESCE(MAX(sys_audit_created_on) - INTERVAL 1 DAY, DATE '1900-01-01')
        FROM {{ this }}
      )
      -- updates due to inputs: new or deleted
      OR {{ input_changed('utm') }} --- esta contiene los nuevos campos channel y subchannel
      OR {{ input_changed('subteam') }}
      OR {{ input_changed('referrer') }}
      OR {{ input_changed('url') }}
      OR {{ input_changed('insti') }}
      OR {{ input_changed('partner_fraud') }}
      OR {{ input_changed('affiliate_classification') }}
      OR {{ input_changed('partner_exception') }}
    )
    {% endif %}