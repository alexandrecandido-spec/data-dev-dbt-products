select
  gmv.year_month_day_code
  , gmv_base.date :: date as completed_at
  , gmv_base.store_id
  , gmv_base.gateway
  , gmv_base.payment
  , gmv_base.shipping
  , gmv_base.storefront
  , gmv_base.currency
  , gmv_base.country_currency
  , gmv_base.platform_type
  , msi.country
  , msi.partner_id
  , msi.mkt_source_first_click
  , msi.mkt_subteam_first_click
  , msi.mkt_source_last_click
  , msi.mkt_subteam_last_click
  , msi.mkt_source_partner_click
  , msi.mkt_subteam_partner_click
  ,sum(gmv_base.total) gmv
  ,sum(gmv_base.total_in_usd) gmv_usd
  ,sum(gmv_base.products) product_quantity
  ,sum(gmv_base.orders) orders_quantity
 from {{ ref('g__operations__orders_gmv_store__agg_daily') }} gmv_base
 left join {{ ref('marketing_merchant_info_refined') }} msi   on msi.store_id = gmv_base.store_id
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18--,19,20,21,22,23,24,25,26