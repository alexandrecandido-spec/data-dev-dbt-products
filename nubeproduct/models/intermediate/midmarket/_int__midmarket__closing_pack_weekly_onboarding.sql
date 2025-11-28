with
	onboarding_churns as
        (select distinct
            o.store_id,
            o.deal_id,
            o.dealname as name,
            o.country as country_code,
            mi.base_region_name as geo_region,
		    mi.base_state_name as geo_state,
		    mi.base_city_name as geo_city,
		    coalesce(mi.vertical_name, 'Not Informed') as vertical,
		    coalesce(o.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
		    o.owner,
            'Onboarding' as metric_group,
		    'Onboarding Churns' as metric_type,
            o.onboarding_churn_week as date_week,
            --case when o.country = 'AR' then o.potential_gmv / fc.value_local_currency else null end as potential_gmv_usd,
            /*case
                when o.country = 'BR' then
                    case 
                        when coalesce(o.potential_gmv, 0) < 100000 then '< 100k'
                        when coalesce(o.potential_gmv, 0) >= 100000 and coalesce(o.potential_gmv, 0) < 400000 then '100k - 400k'
                        when coalesce(o.potential_gmv, 0) >= 400000 and coalesce(o.potential_gmv, 0) < 800000 then '400k - 800k'
                        when coalesce(o.potential_gmv, 0) >= 800000 then '> 800k'
                        else '< 100k'  -- Default for null/edge cases
                    end
                when o.country = 'AR' then
                    case 
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 20000 then '< 20k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 20000 and coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 60000 then '20k - 60k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 60000 and coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 120000 then '60k - 120k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 120000 then '> 120k USD'
                        else '< 20k USD'  -- Default for null/edge cases
                    end
            end as tier,*/
            case 
        		when o.country = 'MX' then
        			case when o.produto_nuvemshop = 'Plano Next / Evolucion - (Mid Market)' then 1 end
    			else 1
        	end total,
            o.potential_gmv,
        	null as actual_gmv,
        	null as actual_gmv_usd,
            o.subscription,
            o.cpt,
            o.potential_gross_profit_perc
    	from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as o
            /*left join midmarket_monthly_currency_values as fc
                on o.country = fc.country
                and o.sales_close_month = fc.period_date*/
    		left join {{ ref('company_metrics_merchant_info') }} as mi
				on o.store_id = mi.store_id
        where 
            o.onboarding_churn_week is not null
            and o.pipeline in 
                ('Onboarding | AR',
                'Onboarding | BR',
                'Onboarding | MX')),
	onboarding_downgrades as
		(select distinct
            o.store_id,
            o.deal_id,
            o.dealname as name,
            o.country as country_code,
            mi.base_region_name as geo_region,
		    mi.base_state_name as geo_state,
		    mi.base_city_name as geo_city,
		    coalesce(mi.vertical_name, 'Not Informed') as vertical,
            coalesce(o.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            o.owner,
            'Onboarding' as metric_group,
		    'Onboarding Downgrades' as metric_type,
            o.onboarding_downgrade_week as date_week,
            --case when o.country = 'AR' then o.potential_gmv / fc.value_local_currency else null end as potential_gmv_usd,
            /*case
                when o.country = 'BR' then
                    case 
                        when coalesce(o.potential_gmv, 0) < 100000 then '< 100k'
                        when coalesce(o.potential_gmv, 0) >= 100000 and coalesce(o.potential_gmv, 0) < 400000 then '100k - 400k'
                        when coalesce(o.potential_gmv, 0) >= 400000 and coalesce(o.potential_gmv, 0) < 800000 then '400k - 800k'
                        when coalesce(o.potential_gmv, 0) >= 800000 then '> 800k'
                        else '< 100k'  -- Default for null/edge cases
                    end
                when o.country = 'AR' then
                    case 
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 20000 then '< 20k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 20000 and coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 60000 then '20k - 60k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 60000 and coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 120000 then '60k - 120k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 120000 then '> 120k USD'
                        else '< 20k USD'  -- Default for null/edge cases
                    end
            end as tier,*/
            case 
        		when o.country = 'MX' then
        			case when o.produto_nuvemshop = 'Plano Next / Evolucion - (Mid Market)' then 1 end
    			else 1
        	end total,
            o.potential_gmv,
       		null as actual_gmv,
        	null as actual_gmv_usd,
            o.subscription,
            o.cpt,
            o.potential_gross_profit_perc
    	from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as o
            /*left join midmarket_monthly_currency_values as fc
                on o.country = fc.country
                and o.sales_close_month = fc.period_date*/
    		left join {{ ref('company_metrics_merchant_info') }} as mi
				on o.store_id = mi.store_id
        where 
            o.onboarding_downgrade_week is not null
            and o.pipeline in 
                ('Onboarding | AR',
                'Onboarding | BR',
                'Onboarding | MX')),
	onboarding_go_lives as
		(select distinct
            o.store_id,
            o.deal_id,
         	o.dealname as name,
            o.country as country_code,
            mi.base_region_name as geo_region,
		    mi.base_state_name as geo_state,
		    mi.base_city_name as geo_city,
		    coalesce(mi.vertical_name, 'Not Informed') as vertical,
            coalesce(o.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            o.owner,
            'Onboarding' as metric_group,
		    'Onboarding Go Lives' as metric_type,
			o.onboarding_go_live_week as date_week,
            --case when o.country = 'AR' then o.potential_gmv / fc.value_local_currency else null end as potential_gmv_usd,
            /*case
                when o.country = 'BR' then
                    case 
                        when coalesce(o.potential_gmv, 0) < 100000 then '< 100k'
                        when coalesce(o.potential_gmv, 0) >= 100000 and coalesce(o.potential_gmv, 0) < 400000 then '100k - 400k'
                        when coalesce(o.potential_gmv, 0) >= 400000 and coalesce(o.potential_gmv, 0) < 800000 then '400k - 800k'
                        when coalesce(o.potential_gmv, 0) >= 800000 then '> 800k'
                        else '< 100k'  -- Default for null/edge cases
                    end
                when o.country = 'AR' then
                    case 
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 20000 then '< 20k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 20000 and coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 60000 then '20k - 60k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 60000 and coalesce(o.potential_gmv, 0) / fc.value_local_currency <= 120000 then '60k - 120k USD'
                        when coalesce(o.potential_gmv, 0) / fc.value_local_currency > 120000 then '> 120k USD'
                        else '< 20k USD'  -- Default for null/edge cases
                    end
            end as tier,*/
            case 
        		when o.country = 'MX' then
        			case when o.produto_nuvemshop = 'Plano Next / Evolucion - (Mid Market)' then 1 end
    			else 1
        	end total,
            o.potential_gmv,
            null as actual_gmv,
        	null as actual_gmv_usd,
            o.subscription,
            o.cpt,
            o.potential_gross_profit_perc
    	from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as o
            /*left join midmarket_monthly_currency_values as fc
                on o.country = fc.country
                and o.sales_close_month = fc.period_date*/
			left join {{ ref('company_metrics_merchant_info') }} as mi
				on o.store_id = mi.store_id
        where 
            o.onboarding_go_live_week is not null
          	and o.pipeline in 
                ('Onboarding | AR',
                'Onboarding | BR',
                'Onboarding | MX'))
select
	*
from onboarding_churns as oc
	union all
select
	*
from onboarding_downgrades as od
	union all
select
	*
from onboarding_go_lives as og

