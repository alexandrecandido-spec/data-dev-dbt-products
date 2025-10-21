select
    mbr.store_id,
    null as deal_id,
    mi.domain as name,
    mbr.country as country_code,
    mi.base_region_name as geo_region,
    mi.base_state_name as geo_state,
    mi.base_city_name as geo_city,
    coalesce(mi.vertical_name, 'Not Informed') as vertical,
    --coalesce(ac.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
    'Success' as metric_group,
    'Success Warnings' as metric_type,
    cast(date_trunc('month', mbr.date_from) as date) as date_month,
    --tiers.group_tier as tier,
    null as potential_gmv,
    gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
    gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
    1 as total
from {{ ref('midmarket_monthly_business_review') }} as mbr
    left join {{ ref('company_metrics_gmv_and_segments') }} as gmv
      on mbr.store_id = gmv.store_id
      and cast(date_trunc('month', mbr.date_from) as date) = cast(date_trunc('month', gmv.datemonth) as date)
    left join {{ ref('company_metrics_merchant_info') }} as mi
      on mbr.store_id = mi.store_id
    /*left join {{ ref('_int_midmarket_closing_pack_franchise_group_tiers')}} as tiers
      on mbr.store_id = tiers.store_id
      and cast(date_trunc('month', mbr.date_from) as date) = tiers.datemonth*/
    /*left join {{ ref('midmarket_closing_pack_deals_acquisition_channel') }} as ac
      on mbr.store_id = ac.store_id*/
where
    mbr.country in ('AR', 'BR', 'MX')
    and mbr.status = 'Warning'
    and mbr.main = true
    and mbr.enterprise_plan = true