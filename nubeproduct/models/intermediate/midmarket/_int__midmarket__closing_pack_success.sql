with
    all_success_deals as
		(
		select distinct
			d.store_id,
			d.deal_id,
			row_number() over (partition by d.store_id order by d.createdate desc) as latest_deal,
			d.acquisition_channel
		from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as d
		where 
			pipeline in 
				(
				'Success | AR',
		        'Success | BR',
		        'Success | MX'
				)
			),
    success_acquisition_channels as
        (
        select
            store_id,
            acquisition_channel
        from all_success_deals as sd
        where 
            latest_deal = 1
        ),
    success_merchants as (
        select
            mbr.store_id,
            null as deal_id,
            mi.domain as name,
            mbr.country as country_code,
            mi.base_region_name as geo_region,
            mi.base_state_name as geo_state,
            mi.base_city_name as geo_city,
            coalesce(mi.vertical_name, 'Not Informed') as vertical,
            coalesce(sac.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            mbr.rep as owner,
            'Success' as metric_group,
            'Success Merchants' as metric_type,
            cast(date_trunc('month', mbr.date_from) as date) as date_month,
            --tiers.group_tier as tier,
            case when mbr.main = true then 1 end total,
            null as potential_gmv,
            gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
            gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
            null as subscription,
            null as cpt,
            null as potential_gross_profit_perc
        from {{ ref('midmarket_monthly_business_review') }} as mbr
            left join {{ ref('company_metrics_gmv_and_segments') }} as gmv
                on mbr.store_id = gmv.store_id
                and cast(date_trunc('month', mbr.date_from) as date) = cast(date_trunc('month', gmv.datemonth) as date)
            left join {{ ref('company_metrics_merchant_info') }} as mi
                on mbr.store_id = mi.store_id
            /*left join {{ ref('_int_midmarket_closing_pack_franchise_group_tiers')}} as tiers
                on mbr.store_id = tiers.store_id
                and cast(date_trunc('month', mbr.date_from) as date) = tiers.datemonth*/
            left join success_acquisition_channels as sac
                on mbr.store_id = sac.store_id
        where
            mbr.country in ('AR', 'BR', 'MX')
            and mbr.playbook not in ('Effective churn', 'Out of portfolio')
            --and mbr.main = true
            and mbr.enterprise_plan = true
        ),
    success_warnings as (
        select
            mbr.store_id,
            null as deal_id,
            mi.domain as name,
            mbr.country as country_code,
            mi.base_region_name as geo_region,
            mi.base_state_name as geo_state,
            mi.base_city_name as geo_city,
            coalesce(mi.vertical_name, 'Not Informed') as vertical,
            coalesce(sac.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            mbr.rep as owner,
            'Success' as metric_group,
            'Success Warnings' as metric_type,
            cast(date_trunc('month', mbr.date_from) as date) as date_month,
            --tiers.group_tier as tier,
            case when mbr.main = true then 1 end total,
            null as potential_gmv,
            gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
            gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
            null as subscription,
            null as cpt,
            null as potential_gross_profit_perc
        from {{ ref('midmarket_monthly_business_review') }} as mbr
            left join {{ ref('company_metrics_gmv_and_segments') }} as gmv
            on mbr.store_id = gmv.store_id
            and cast(date_trunc('month', mbr.date_from) as date) = cast(date_trunc('month', gmv.datemonth) as date)
            left join {{ ref('company_metrics_merchant_info') }} as mi
            on mbr.store_id = mi.store_id
            /*left join {{ ref('_int_midmarket_closing_pack_franchise_group_tiers')}} as tiers
            on mbr.store_id = tiers.store_id
            and cast(date_trunc('month', mbr.date_from) as date) = tiers.datemonth*/
            left join success_acquisition_channels as sac
                on mbr.store_id = sac.store_id
        where
            mbr.country in ('AR', 'BR', 'MX')
            and mbr.status = 'Warning'
            --and mbr.main = true
            and mbr.enterprise_plan = true
        ),
    success_unknowns as (
        select
            mbr.store_id,
            null as deal_id,
            mi.domain as name,
            mbr.country as country_code,
            mi.base_region_name as geo_region,
            mi.base_state_name as geo_state,
            mi.base_city_name as geo_city,
            coalesce(mi.vertical_name, 'Not Informed') as vertical,
            coalesce(sac.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            mbr.rep as owner,
            'Success' as metric_group,
            'Success Unknowns' as metric_type,
            cast(date_trunc('month', mbr.date_from) as date) as date_month,
            --tiers.group_tier as tier,
            case when mbr.main = true then 1 end total,
            null as potential_gmv,
            gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
            gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
            null as subscription,
            null as cpt,
            null as potential_gross_profit_perc
        from {{ ref('midmarket_monthly_business_review') }} as mbr
            left join {{ ref('company_metrics_gmv_and_segments') }} as gmv
                on mbr.store_id = gmv.store_id
                and cast(date_trunc('month', mbr.date_from) as date) = cast(date_trunc('month', gmv.datemonth) as date)
            left join {{ ref('company_metrics_merchant_info') }} as mi
                on mbr.store_id = mi.store_id
            /*left join {{ ref('_int_midmarket_closing_pack_franchise_group_tiers')}} as tiers
            on mbr.store_id = tiers.store_id
            and cast(date_trunc('month', mbr.date_from) as date) = tiers.datemonth*/
            left join success_acquisition_channels as sac
                on mbr.store_id = sac.store_id
        where
            mbr.country in ('AR', 'BR', 'MX')
            and mbr.status = 'Unknown'
            --and mbr.main = true
            and mbr.enterprise_plan = true
        ),
    success_out_of_portfolio as (
        select
            d.store_id,
            d.deal_id,
            d.dealname as name,
            d.country as country_code,
            mi.base_region_name as geo_region,
            mi.base_state_name as geo_state,
            mi.base_city_name as geo_city,
            coalesce(mi.vertical_name, 'Not Informed') as vertical,
            coalesce(d.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            mbr.rep as owner,
            'Success' as metric_group,
            'Success Out of Portfolio' as metric_type,
            d.out_of_portfolio_month as date_month,
            --tiers.tier,
            case when mbr.main = true then 1 end total,
            d.potential_gmv,
            gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
            gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
            d.subscription,
            d.cpt,
            d.potential_gross_profit_perc
        from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as d
            left join {{ ref('midmarket_monthly_business_review') }} as mbr
                on d.store_id = mbr.store_id 
                and d.out_of_portfolio_month = mbr.date_from
            left join {{ ref('company_metrics_merchant_info') }} as mi
                on d.store_id = mi.store_id
            /*left join {{ ref('_int_midmarket_closing_pack_individual_tiers')}} as tiers
                on d.store_id = tiers.store_id
                and d.out_of_portfolio_month = tiers.datemonth*/
            left join {{ ref('company_metrics_gmv_and_segments') }} as gmv
                on d.store_id = gmv.store_id
                and d.out_of_portfolio_month = cast(date_trunc('month', gmv.datemonth) as date)
        where 
            d.pipeline in 
                ('Success | AR',
                'Success | BR',
                'Success | MX')
            and d.dealstage = 'Out of portfolio'
            and d.out_of_portfolio_root_cause not in (
                '[AR only] Success: other store downgrade (choose only if we are not losing subscription fee)',
                'Not Next/Evolución'
            )
        ),
    success_churns as (
        select
            c.store_id,
            c.deal_id,
            c.dealname as name,
            c.country as country_code,
            mi.base_region_name as geo_region,
            mi.base_state_name as geo_state,
            mi.base_city_name as geo_city,
            coalesce(mi.vertical_name, 'Not Informed') as vertical,
            coalesce(c.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            mbr.rep as owner,
            'Success' as metric_group,
            'Success Churns' as metric_type,
            c.churn_month as date_month,
            --tiers.tier,
            case when mbr.main = true then 1 end total,
            c.potential_gmv,
            gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
            gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
            c.subscription,
            c.cpt,
            c.potential_gross_profit_perc
        from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as c
            left join {{ ref('midmarket_monthly_business_review') }} as mbr
                on c.store_id = mbr.store_id 
                and c.churn_month = mbr.date_from
            left join {{ ref('company_metrics_merchant_info') }} as mi
                on c.store_id = mi.store_id
            /*left join {{ ref('_int_midmarket_closing_pack_individual_tiers')}} as tiers
                on c.store_id = tiers.store_id
                and c.churn_month = tiers.datemonth*/
            left join {{ ref('company_metrics_gmv_and_segments' )}} as gmv
                on c.store_id = gmv.store_id
                and c.churn_month = cast(date_trunc('month', gmv.datemonth) as date)
        where
            c.pipeline in 
                ('Success | AR',
                'Success | BR',
                'Success | MX')
            and c.dealstage = 'Effective churn'
            and (
            -- For BR: always passes
            c.country not in ('AR','MX')
            -- For AR/MX: exclude only if it is exactly that reason (NULL passes)
            or c.effective_churn_root_cause is distinct from
            '[AR only] Success: other store no seller closed (choose only if we are not losing subscription fee)'
            )
        )
select * from success_merchants
    union all
select * from success_warnings
    union all
select * from success_unknowns
    union all
select * from success_out_of_portfolio
    union all
select * from success_churns