select
  gmv.year_month_day_code
  , gmv.completed_at :: date
  , gmv.store_id
  , gmv.gateway
  , gmv.payment
  , gmv.shipping
  , gmv.storefront
  , gmv.currency
  , gmv.country_currency
  , gmv.platform_type
  , msi.country
  , msi.partner_code
  , msi.mkt_source_first_click
  , msi.mkt_subteam_first_click
  , msi.mkt_source_last_click
  , msi.mkt_subteam_last_click
  , msi.mkt_source_partner_click
  , msi.mkt_subteam_partner_click
  , seg.gmv_local_currency_monthly as gmv_30d
  , seg.gmv_usd_monthly as gmv_usd_30d
  , (seg.orders_on_platform_monthly + seg.orders_off_platform_monthly) as orders_30d
  , seg.gmv_local_currency_90d as gmv_90d
  , seg.gmv_usd_90d as gmv_usd_90d  
  , seg.orders_general_90d as orders_90d
  , seg.segment as historical_segment
  ,sum(gmv.total) gmv
  ,sum(gmv.total_in_usd) gmv_usd
  ,sum(gmv.product_quantity) product_quantity
  ,count(distinct id) orders_quantity
 from {{ ref('company_metrics_paid_orders') }} gmv
 left join {{ ref('marketing_merchant_info_refined') }} msi   on msi.store_id = gmv.store_id
 left join {{ ref('company_metrics_gmv_and_segments') }} seg  on seg.store_id=gmv.store_id 
                                                        and seg.year_month_code = substring(cast(gmv.year_month_day_code as string),1,6)
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25