with
	six_months_filter as 
		(select 
			date_add(MONTH, -5, max(date_trunc('month', f.datemonth)))
		from {{ ref('company_metrics_gmv_and_segments') }} f
		),
	three_months_filter as 
		(select 
			date_add(MONTH, -2, max(date_trunc('month', f.datemonth)))
		from {{ ref('company_metrics_gmv_and_segments') }} f
		),
-- Last 6 calendar months by store
	sm as 
		(select
		    store_id,
		    sum(gmv_usd_monthly)                             as six_months_gmv_usd_sum,
		    sum(gmv_local_currency_monthly)                  as six_months_gmv_local_currency_sum,
		    sum(gmv_usd_on_platform_monthly)                 as six_months_gmv_usd_on_platform_sum,
		    sum(gmv_local_currency_on_platform_monthly)      as six_months_gmv_local_currency_on_platform_sum,
		    sum(orders_on_platform_monthly)                  as six_months_orders_on_platform_sum,
		    count(*)                                         as six_month_count
	    from (
	    	select
	    		store_id,
	    		date_trunc('month', f.datemonth)             as month_date,
	    		gmv_usd_monthly,
	    		gmv_local_currency_monthly,
	    		gmv_usd_on_platform_monthly,
	    		gmv_local_currency_on_platform_monthly,
	    		orders_on_platform_monthly
			from {{ ref('company_metrics_gmv_and_segments') }} f
			where 
				date_trunc('month', f.datemonth) >= (select * from six_months_filter)
	  			and f.country in ('AR','BR','MX')
	  		) sm_sub
  		group by store_id
		),
-- Last 3 calendar months by store
	tm as 
		(select
		    store_id,
		    sum(gmv_usd_monthly)                             as three_months_gmv_usd_sum,
		    sum(gmv_local_currency_monthly)                  as three_months_gmv_local_currency_sum,
		    sum(gmv_usd_on_platform_monthly)                 as three_months_gmv_usd_on_platform_sum,
		    sum(gmv_local_currency_on_platform_monthly)      as three_months_gmv_local_currency_on_platform_sum,
		    sum(orders_on_platform_monthly)                  as three_months_orders_on_platform_sum,
		    count(*)                                         as three_month_count
	    from (
		    select
		    	store_id,
		    	date_trunc('month', f.datemonth)             as month_date,
		    	gmv_usd_monthly,
		    	gmv_local_currency_monthly,
		    	gmv_usd_on_platform_monthly,
		    	gmv_local_currency_on_platform_monthly,
		    	orders_on_platform_monthly
		    from {{ ref('company_metrics_gmv_and_segments') }} f
		    where 
		    	date_trunc('month', f.datemonth) >= (select * from three_months_filter)
		    	and f.country in ('AR','BR','MX')
		  ) tm_sub
	  group by store_id
	  ),
	finance_data as 
		(select
		    f.store_id,
		    date_trunc('month', f.datemonth)                 as last_finance_month,
		    f.segment_on_platform			 				 as last_month_segment_on_platform,
		    -- Last month data
		    round(f.gmv_usd_monthly)                         as gmv_usd_last_month,
		    round(f.gmv_local_currency_monthly)              as gmv_last_month,
		    round(f.gmv_usd_on_platform_monthly)             as gmv_usd_on_platform_last_month,
		    round(f.gmv_local_currency_on_platform_monthly)  as gmv_on_platform_last_month,
		    f.orders_on_platform_monthly                     as orders_on_platform_last_month,
		    -- 6 months average (only when all months are present)
		    case when sm.six_month_count = 6
		      then round(sm.six_months_gmv_usd_sum / 6) end                        as gmv_usd_six_months_avg,
		    case when sm.six_month_count = 6
		      then round(sm.six_months_gmv_local_currency_sum / 6) end             as gmv_six_months_avg,
		    case when sm.six_month_count = 6
		      then round(sm.six_months_gmv_usd_on_platform_sum / 6) end            as gmv_usd_on_platform_six_months_avg,
		    case when sm.six_month_count = 6
		      then round(sm.six_months_gmv_local_currency_on_platform_sum / 6) end as gmv_on_platform_six_months_avg,
		    case when sm.six_month_count = 6
		      then round(sm.six_months_orders_on_platform_sum / 6) end             as orders_on_platform_six_months_avg,
		    -- 3 months average (only when all months are present)
		    case when tm.three_month_count = 3
		      then round(tm.three_months_gmv_usd_sum / 3) end                        as gmv_usd_three_months_avg,
		    case when tm.three_month_count = 3
		      then round(tm.three_months_gmv_local_currency_sum / 3) end             as gmv_three_months_avg,
		    case when tm.three_month_count = 3
		      then round(tm.three_months_gmv_usd_on_platform_sum / 3) end            as gmv_usd_on_platform_three_months_avg,
		    case when tm.three_month_count = 3
		      then round(tm.three_months_gmv_local_currency_on_platform_sum / 3) end as gmv_on_platform_three_months_avg,
		    case when tm.three_month_count = 3
		      then round(tm.three_months_orders_on_platform_sum / 3) end             as orders_on_platform_three_months_avg
		from {{ ref('company_metrics_gmv_and_segments') }} f
			left join sm 
				on f.store_id = sm.store_id
			left join tm 
				on f.store_id = tm.store_id
		where 
			f.country in ('AR','BR','MX')
			and f.datemonth = (select max(datemonth) from {{ ref('company_metrics_gmv_and_segments') }})
		)
select
  store_id,
  last_finance_month,
  last_month_segment_on_platform,
  gmv_usd_last_month,
  gmv_last_month,
  gmv_usd_on_platform_last_month,
  gmv_on_platform_last_month,
  orders_on_platform_last_month,
  gmv_usd_six_months_avg,
  gmv_six_months_avg,
  gmv_usd_on_platform_six_months_avg,
  gmv_on_platform_six_months_avg,
  orders_on_platform_six_months_avg,
  gmv_usd_three_months_avg,
  gmv_three_months_avg,
  gmv_usd_on_platform_three_months_avg,
  gmv_on_platform_three_months_avg,
  orders_on_platform_three_months_avg
from finance_data as fd