with 
	renewal as
		(select distinct
			r.store_id,
			r.deal_id,
			r.dealname as name,
			r.country as country_code,
			mi.base_region_name as geo_region,
		    mi.base_state_name as geo_state,
		    mi.base_city_name as geo_city,
		    coalesce(mi.vertical_name, 'Not Informed') as vertical,
		    coalesce(r.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
			r.owner,
			'Upsell & Renewal' as metric_group,
		    'Renewals' as metric_type,
			r.close_month as date_month,
			--case when r.country = 'AR' then r.potential_gmv / fc.value_local_currency else null end as potential_gmv_usd,
			/*case
				when r.country = 'BR' then
					case 
						when coalesce(r.potential_gmv, 0) < 100000 then '< 100k'
						when coalesce(r.potential_gmv, 0) >= 100000 and coalesce(r.potential_gmv, 0) < 400000 then '100k - 400k'
						when coalesce(r.potential_gmv, 0) >= 400000 and coalesce(r.potential_gmv, 0) < 800000 then '400k - 800k'
						when coalesce(r.potential_gmv, 0) >= 800000 then '> 800k'
						else '< 100k'  -- Default for null/edge cases
					end
				when r.country = 'AR' then
					case 
						when coalesce(r.potential_gmv, 0) / fc.value_local_currency <= 20000 then '< 20k USD'
						when coalesce(r.potential_gmv, 0) / fc.value_local_currency > 20000 and coalesce(r.potential_gmv, 0) / fc.value_local_currency <= 60000 then '20k - 60k USD'
						when coalesce(r.potential_gmv, 0) / fc.value_local_currency > 60000 and coalesce(r.potential_gmv, 0) / fc.value_local_currency <= 120000 then '60k - 120k USD'
						when coalesce(r.potential_gmv, 0) / fc.value_local_currency > 120000 then '> 120k USD'
						else '< 20k USD'  -- Default for null/edge cases
					end
				else null  -- Mexico not included for now
			end as tier,*/
			case when mbr.main = true then 1 end total,
			r.potential_gmv,
			gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
		    gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
			r.subscription,
			r.cpt,
			r.potential_gross_profit_perc
	from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as r
		    left join {{ ref('midmarket_monthly_business_review') }} as mbr
				on r.store_id = mbr.store_id 
				and r.close_month = mbr.date_from
			left join {{ ref('company_metrics_merchant_info') }} as mi
				on r.store_id = mi.store_id
		    left join {{ ref('company_metrics_gmv_and_segments') }} as gmv
		        on r.store_id = gmv.store_id
		        and r.close_month = cast(date_trunc('month', gmv.datemonth) as date)
			where 
				r.pipeline in 
					('Upsell Success | AR',
					'Upsell Success | BR',
					'Upsell Success | MX')
				and r.dealstage = 'NEXT Renewal'
				and r.client_upsell_motive = 'Renewal'
				and r.country = 'BR'),
	upsell as
		(select distinct
			u.store_id,
			u.deal_id,
			u.dealname as name,
			u.country as country_code,
			mi.base_region_name as geo_region,
		    mi.base_state_name as geo_state,
		    mi.base_city_name as geo_city,
		    coalesce(mi.vertical_name, 'Not Informed') as vertical,
		    coalesce(u.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
			u.owner,
			'Upsell & Renewal' as metric_group,
		    'Upsells' as metric_type,
			u.close_month as date_month,
			--case when u.country = 'AR' then u.potential_gmv / fc.value_local_currency else null end as potential_gmv_usd,
			/*case
				when u.country = 'BR' then
					case 
						when coalesce(u.potential_gmv, 0) < 100000 then '< 100k'
						when coalesce(u.potential_gmv, 0) >= 100000 and coalesce(u.potential_gmv, 0) < 400000 then '100k - 400k'
						when coalesce(u.potential_gmv, 0) >= 400000 and coalesce(u.potential_gmv, 0) < 800000 then '400k - 800k'
						when coalesce(u.potential_gmv, 0) >= 800000 then '> 800k'
						else '< 100k'  -- Default for null/edge cases
					end
				when u.country = 'AR' then
					case 
						when coalesce(u.potential_gmv, 0) / fc.value_local_currency <= 20000 then '< 20k USD'
						when coalesce(u.potential_gmv, 0) / fc.value_local_currency > 20000 and coalesce(u.potential_gmv, 0) / fc.value_local_currency <= 60000 then '20k - 60k USD'
						when coalesce(u.potential_gmv, 0) / fc.value_local_currency > 60000 and coalesce(u.potential_gmv, 0) / fc.value_local_currency <= 120000 then '60k - 120k USD'
						when coalesce(u.potential_gmv, 0) / fc.value_local_currency > 120000 then '> 120k USD'
						else '< 20k USD'  -- Default for null/edge cases
					end
				else null  -- Mexico not included for now
			end as tier,*/
			1 as total,
			u.potential_gmv,
			gmv.gmv_local_currency_on_platform_monthly as actual_gmv,
		    gmv.gmv_usd_on_platform_monthly as actual_gmv_usd,
			u.subscription,
			u.cpt,
			u.potential_gross_profit_perc
		from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as u
			left join {{ ref('company_metrics_merchant_info') }} as mi
				on u.store_id = mi.store_id
		    left join {{ ref('company_metrics_gmv_and_segments') }} as gmv
		        on u.store_id = gmv.store_id
		        and u.close_month = cast(date_trunc('month', gmv.datemonth) as date)
			where 
				u.pipeline in 
					('Upsell Success | AR',
					'Upsell Success | BR',
					'Upsell Success | MX')
				and u.dealstage in ('Upsell','Won')
				and u.client_upsell_motive = 'Upsell'
				and u.country in ('AR', 'BR', 'MX'))
	select
		*
	from renewal
		union all
	select
		*
	from upsell