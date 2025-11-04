with 
	gmv as
		(select 
			store_id,
			datemonth,
			gmv_local_currency_on_platform_monthly,
			gmv_local_currency_on_platform_90d,
			row_number() over (partition by store_id order by datemonth desc) as gmv_months
		from {{ ref('company_metrics_gmv_and_segments') }})
select
	store_id,
	round(gmv_local_currency_on_platform_monthly) as gmv_local_currency_on_platform_monthly,
	round(gmv_local_currency_on_platform_90d) as gmv_local_currency_on_platform_90d
from gmv
where 
	gmv_months = 1
	and datemonth = (select max(datemonth) from {{ ref('company_metrics_gmv_and_segments') }})