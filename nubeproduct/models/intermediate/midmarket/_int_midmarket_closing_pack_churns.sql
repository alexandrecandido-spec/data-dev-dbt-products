select
    c.store_id,
    c.deal_id,
    c.dealname as name,
    c.country as country_code,
    mi.base_region_name as geo_region,
    mi.base_state_name as geo_state,
    mi.base_city_name as geo_city,
    coalesce(mi.vertical_name, 'Not Informed') as vertical,
    --coalesce(c.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
    'Success' as metric_group,
    'Success Churns' as metric_type,
    c.churn_month as date_month,
    --tiers.tier,
    c.potential_gmv,
    gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
    gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
    1 as total
from {{ ref('midmarket_closing_pack_deals_churn') }} as c
    left join {{ ref('midmarket_monthly_business_review') }} as mbr
        on c.store_id = mbr.store_id 
        and c.churn_month = mbr.date_from
    left join {{ ref('company_metrics_merchant_info') }} as mi
        on c.store_id = mi.store_id
    /*left join {{ ref('_int_midmarket_closing_pack_individual_tiers')}} as tiers
        on c.store_id = tiers.store_id
        and c.churn_month = tiers.datemonth*/
    /*left join {{ ref('midmarket_closing_pack_deals_acquisition_channel') }} as ac
        on c.store_id = ac.store_id*/
    left join {{ ref('company_metrics_gmv_and_segments' )}} as gmv
        on c.store_id = gmv.store_id
        and c.churn_month = cast(date_trunc('month', gmv.datemonth) as date)
where
    (
    -- For BR: always passes
    c.country not in ('AR','MX')
    -- For AR/MX: exclude only if it is exactly that reason (NULL passes)
    or c.effective_churn_root_cause is distinct from
    '[AR only] Success: other store no seller closed (choose only if we are not losing subscription fee)'
    )
    and mbr.main = true