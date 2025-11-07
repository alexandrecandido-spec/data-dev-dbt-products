with
	sales_sqls as
		(select
			s.store_id,
            s.deal_id,
            s.dealname as name,
            s.country as country_code,
            null as geo_region,
    		split(s.cidade_territorio_sales, '/')[2] AS geo_state,
            split(s.cidade_territorio_sales, '/')[1] AS geo_city,
		    coalesce(s.hubspot_vertical, 'Not Informed') as vertical,
		    coalesce(s.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            s.owner,
		    'Sales' as metric_group,
		    'Sales SQLs' as metric_type,
            coalesce(s.sales_date_entered_scheduled_meetings_month, sales_date_entered_problem_discovery_month) as date_month,
            --case when s.country = 'AR' then s.amount / fc.value_local_currency else null end as potential_gmv_usd,
            /*case
                when s.country = 'BR' then
                    case 
                        when coalesce(s.amount, 0) < 100000 then '< 100k'
                        when coalesce(s.amount, 0) >= 100000 and coalesce(s.amount, 0) < 400000 then '100k - 400k'
                        when coalesce(s.amount, 0) >= 400000 and coalesce(s.amount, 0) < 800000 then '400k - 800k'
                        when coalesce(s.amount, 0) >= 800000 then '> 800k'
                        else '< 100k'  -- Default for null/edge cases
                    end
                when s.country = 'AR' then
                    case 
                        when coalesce(s.amount, 0) / fc.value_local_currency <= 20000 then '< 20k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 20000 and coalesce(s.amount, 0) / fc.value_local_currency <= 60000 then '20k - 60k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 60000 and coalesce(s.amount, 0) / fc.value_local_currency <= 120000 then '60k - 120k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 120000 then '> 120k USD'
                        else '< 20k USD'  -- Default for null/edge cases
                    end
            end as tier,*/
            1 as total,
            null as potential_gmv,
        	null as actual_gmv,
        	null as actual_gmv_usd,
        	null as subscription,
        	null as cpt,
        	null as potential_gross_profit_perc
		from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as s
		where 
		    pipeline in 
                ('Sales | AR',
                'Sales | BR',
                'Sales | MX')
            and coalesce(s.sales_date_entered_scheduled_meetings_month, s.sales_date_entered_problem_discovery_month) is not null
		    and s.segmento_nuvemshop = 'Mid Market plan'
		    and s.acquisition_channel in ('Inbound','Events')),
	sales_opportunities as
		(select
			s.store_id,
            s.deal_id,
            s.dealname as name,
            s.country as country_code,
            null as geo_region,
		    split(s.cidade_territorio_sales, '/')[2] AS geo_state,
            split(s.cidade_territorio_sales, '/')[1] AS geo_city,
		    coalesce(s.hubspot_vertical, 'Not Informed') as vertical,
		    coalesce(s.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            s.owner,
            'Sales' as metric_group,
		    'Sales Opportunities' as metric_type,
            s.sales_date_entered_problem_discovery_month as date_month,
            --case when s.country = 'AR' then s.amount / fc.value_local_currency else null end as potential_gmv_usd,
            /*case
                when s.country = 'BR' then
                    case 
                        when coalesce(s.amount, 0) < 100000 then '< 100k'
                        when coalesce(s.amount, 0) >= 100000 and coalesce(s.amount, 0) < 400000 then '100k - 400k'
                        when coalesce(s.amount, 0) >= 400000 and coalesce(s.amount, 0) < 800000 then '400k - 800k'
                        when coalesce(s.amount, 0) >= 800000 then '> 800k'
                        else '< 100k'  -- Default for null/edge cases
                    end
                when s.country = 'AR' then
                    case 
                        when coalesce(s.amount, 0) / fc.value_local_currency <= 20000 then '< 20k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 20000 and coalesce(s.amount, 0) / fc.value_local_currency <= 60000 then '20k - 60k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 60000 and coalesce(s.amount, 0) / fc.value_local_currency <= 120000 then '60k - 120k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 120000 then '> 120k USD'
                        else '< 20k USD'  -- Default for null/edge cases
                    end
            end as tier,*/
            case when s.subscription <> 0 or s.subscription is null then 1 end as total,
            s.amount as potential_gmv,
        	null as actual_gmv,
        	null as actual_gmv_usd,
            null as subscription,
            null as cpt,
            null as potential_gross_profit_perc
		from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as s
		where 
		    pipeline in 
                ('Sales | AR',
                'Sales | BR',
                'Sales | MX')
            and s.sales_date_entered_problem_discovery_month is not null
		    and produto_nuvemshop = 'Plano Next / Evolucion - (Mid Market)'),
	sales_new_contracts as
		(select
			s.store_id,
            s.deal_id,
            s.dealname as name,
            s.country as country_code,
            null as geo_region,
		    split(s.cidade_territorio_sales, '/')[2] AS geo_state,
            split(s.cidade_territorio_sales, '/')[1] AS geo_city,
		    coalesce(s.hubspot_vertical, 'Not Informed') as vertical,
		    coalesce(s.acquisition_channel, 'Unknown acquisition channel') as acquisition_channel,
            s.owner,
            'Sales' as metric_group,
		    'Sales New Contracts' as metric_type,
            s.close_month as date_month,
            --case when s.country = 'AR' then s.amount / fc.value_local_currency else null end as potential_gmv_usd,
            /*case
                when s.country = 'BR' then
                    case 
                        when coalesce(s.amount, 0) < 100000 then '< 100k'
                        when coalesce(s.amount, 0) >= 100000 and coalesce(s.amount, 0) < 400000 then '100k - 400k'
                        when coalesce(s.amount, 0) >= 400000 and coalesce(s.amount, 0) < 800000 then '400k - 800k'
                        when coalesce(s.amount, 0) >= 800000 then '> 800k'
                        else '< 100k'  -- Default for null/edge cases
                    end
                when s.country = 'AR' then
                    case 
                        when coalesce(s.amount, 0) / fc.value_local_currency <= 20000 then '< 20k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 20000 and coalesce(s.amount, 0) / fc.value_local_currency <= 60000 then '20k - 60k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 60000 and coalesce(s.amount, 0) / fc.value_local_currency <= 120000 then '60k - 120k USD'
                        when coalesce(s.amount, 0) / fc.value_local_currency > 120000 then '> 120k USD'
                        else '< 20k USD'  -- Default for null/edge cases
                    end
            end as tier,*/
            case when s.subscription > 0 and s.subscription is not null then 1 end as total,
            s.amount as potential_gmv,
        	null as actual_gmv,
        	null as actual_gmv_usd,
            s.subscription,
            s.cpt,
            s.potential_gross_profit_perc
		from {{ ref('midmarket__general__closing_pack_hubspot_deals') }} as s
		where 
		    pipeline in 
                ('Sales | AR',
                'Sales | BR',
                'Sales | MX')
            and s.close_month is not null
		    and s.dealstage = 'Won'
		    and s.produto_nuvemshop = 'Plano Next / Evolucion - (Mid Market)')
	select * from sales_sqls
	    union all
    select * from sales_opportunities
	    union all
	select * from sales_new_contracts