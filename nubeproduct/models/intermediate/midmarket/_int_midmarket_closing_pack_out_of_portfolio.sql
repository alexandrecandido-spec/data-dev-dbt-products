select
    d.store_id,
    d.deal_id,
    d.dealname as name,
    d.country as country_code,
    mi.base_region_name as geo_region,
    mi.base_state_name as geo_state,
    mi.base_city_name as geo_city,
    coalesce(mi.vertical_name, 'Not Informed') as vertical,
	--coalesce(d.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
    'Success' as metric_group,
    'Success Out of Portfolio' as metric_type,
    d.out_of_portfolio_month as date_month,
	--tiers.tier,
    d.potential_gmv,
    gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
    gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
    1 as total
from {{ ref('midmarket_closing_pack_deals_out_of_portfolio') }} as d
    left join {{ ref('midmarket_monthly_business_review') }} as mbr
        on d.store_id = mbr.store_id 
        and d.out_of_portfolio_month = mbr.date_from
    left join {{ ref('company_metrics_merchant_info') }} as mi
        on d.store_id = mi.store_id
    /*left join {{ ref('_int_midmarket_closing_pack_individual_tiers')}} as tiers
        on d.store_id = tiers.store_id
        and d.out_of_portfolio_month = tiers.datemonth*/
    /*left join {{ ref('midmarket_closing_pack_deals_acquisition_channel') }} as ac
        on d.store_id = ac.store_id*/
    left join {{ ref('company_metrics_gmv_and_segments') }} as gmv
        on d.store_id = gmv.store_id
        and d.out_of_portfolio_month = cast(date_trunc('month', gmv.datemonth) as date)
where 
    d.out_of_portfolio_root_cause not in (
        '[AR only] Success: other store downgrade (choose only if we are not losing subscription fee)',
        'Not Next/Evolución'
    )
    and mbr.main = true