-- depends_on: {{ ref('s__traffic__cart_checkout_funnel__event') }}
{{
    config(
        materialized='table',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=["monthly-4th-12pm"]
    )
}}

with gmv_monthly as(
SELECT store_id, avg(gmv_usd_monthly) as avg_monthly 
FROM {{ ref('company_metrics_gmv_and_segments') }} 
where datemonth between date_add(month, -4, current_date) and current_date
group by 1)
select 
i.store_id,
	case 
		when masi.custom_theme is not null then 'FTP Open'
		else 'FTP Closed' end as FTP,
	i.country_code,
	i.current_segment_name,
	o.option_value,
    i.vertical_name,
	avg_monthly,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from 
	 {{ ref('company_metrics_merchant_info') }} i  
		left join {{ ref('product__general__store_options__event') }} o on i.store_id = o.store_id and o.option_name = 'twig_template' 
		left join {{ ref('merchant__attributes__store_info__ref') }} masi on masi.store_id = i.store_id
		left join gmv_monthly gm on i.store_id = gm.store_id