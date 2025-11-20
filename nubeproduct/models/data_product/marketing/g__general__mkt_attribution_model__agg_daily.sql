{{ config(
    materialized = 'incremental',
    unique_key = ['row_key'],
    partition_by = ['year_month_day_code'],
    on_schema_change = 'fail',
    tags = ['daily-10am']
) }}

WITH 

existing_data AS (
  {{ get_existing_data(this, [ 'row_key', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

, base as (
  select * from {{ ref('_int__marketing_attribution_model_gold_created_at_metrics') }}
  union all
  select * from {{ ref('_int__marketing_attribution_model_gold_first_payment_metrics') }}
  union all
  select * from {{ ref('_int__marketing_attribution_model_gold_first_seller_at_metrics') }}
) --- datos a partir del 2018-01-01

, main_source as (
select
  cast(date as date) as date
  , cast(date_format(date, 'yyyyMMdd') as integer) as year_month_day_code
  , store_id
  , country_code
  , source
  , medium
  , campaign
  , content
  , referrer_domain
  , referrer_path
  , landing_page_domain
  , landing_page_path
  , register_url
  , partner_id
  , mkt_source
  , mkt_subteam

  -- trials por created_at
  , coalesce(sum(trials_last_click), 0)  as trials_last_click
  , coalesce(sum(trials_first_click), 0) as trials_first_click
  , coalesce(sum(trials_mean_click), 0)  as trials_mean_click

  -- qls por created_at
  , coalesce(sum(qls_last_click), 0)     as qls_last_click
  , coalesce(sum(qls_first_click), 0)    as qls_first_click
  , coalesce(sum(qls_mean_click), 0)     as qls_mean_click

  -- new payments por first_payment
  , coalesce(sum(new_payment_last_click), 0)  as new_payments_last_click
  , coalesce(sum(new_payment_first_click), 0) as new_payments_first_click
  , coalesce(sum(new_payment_mean_click), 0)  as new_payments_mean_click

  -- new sellers por first_seller_at
  , coalesce(sum(new_seller_last_click), 0)  as new_sellers_last_click
  , coalesce(sum(new_seller_first_click), 0) as new_sellers_first_click
  , coalesce(sum(new_seller_mean_click), 0)  as new_sellers_mean_click

  /*-- métricas para cálculos de CVR --*/
  -- payments por created_at (CVR trial a payment)
  , coalesce(sum(payment_created_at_last_click), 0)  as payment_created_at_last_click
  , coalesce(sum(payment_created_at_first_click), 0) as payment_created_at_first_click
  , coalesce(sum(payment_created_at_mean_click), 0)  as payment_created_at_mean_click

  -- new sellers por created_at (CVR trial a seller)
  , coalesce(sum(new_seller_created_at_last_click), 0)  as new_seller_created_at_last_click
  , coalesce(sum(new_seller_created_at_first_click), 0) as new_seller_created_at_first_click
  , coalesce(sum(new_seller_created_at_mean_click), 0)  as new_seller_created_at_mean_click
  
  -- new sellers por first_payment (CVR NP a seller)  
  , coalesce(sum(new_seller_fpd_last_click), 0)  as new_seller_fpd_last_click
  , coalesce(sum(new_seller_fpd_first_click), 0) as new_seller_fpd_first_click
  , coalesce(sum(new_seller_fpd_mean_click), 0)  as new_seller_fpd_mean_click

  , max(max_sys_audit_updated_on) as max_sys_audit_updated_on
  , lower(
      hex(
        md5(
          concat_ws(
            '|',
            cast(date as varchar(10)),
            cast(store_id as varchar(10)),
            coalesce(source, ''),
            coalesce(medium, ''),
            coalesce(campaign, ''),
            coalesce(content, ''),
            coalesce(referrer_domain, ''),
            coalesce(referrer_path, ''),
            coalesce(landing_page_domain, ''),
            coalesce(landing_page_path, ''),
            coalesce(register_url, ''),
            coalesce(mkt_source, ''),
            coalesce(mkt_subteam, '')
          )
        )
      )
    ) as row_key
FROM base
GROUP BY 
  date, year_month_day_code, store_id, country_code, source, medium, campaign, content,
  referrer_domain, referrer_path, landing_page_domain, landing_page_path,
  register_url, partner_id, mkt_source, mkt_subteam, row_key
)

SELECT
  main_source.*
  , COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
  , COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
  , current_timestamp AS sys_audit_updated_on
  , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM main_source 
LEFT JOIN existing_data e ON main_source.row_key = e.row_key

WHERE 
{% if not is_incremental() %}
      main_source.date >= DATE '2018-01-01'
    {% endif %}
{% if is_incremental() %}
      main_source.max_sys_audit_updated_on > (
        SELECT COALESCE(MAX(sys_audit_created_on) - INTERVAL 1 DAY, DATE '1900-01-01')
        FROM {{ this }}
      )
    {% endif %}