with warnings as (
select 
sw.date_from,
sw.date_to,
sw.store_id, 
msi.country_code,
'warnings' as origen,
case when lower(sw.warning_root_cause_1) like '%pricing%' then 'Pricing'
	when lower(sw.warning_root_cause_1) like '%issue%' then 'Issues' 
	when lower(sw.warning_root_cause_1) like '%problem%' then 'Problems' 
	when lower(sw.warning_root_cause_1) like '%downtime%' then 'Downtime'
	when lower(sw.warning_root_cause_1) like '%nuvem%' then 'Nuvem Pago/Pago Nube'
	when lower(sw.warning_root_cause_1) like '%success: sales%' then 'Low GMV'
	when lower(sw.warning_root_cause_1) like '%success: not able%' or (sw.store_id = 1193991 and sw.date_from < '2024-07-30') then 'Not able to contact merchant' 
else 'Others' end as cause,
case when date_from between date_entered_warning::date and coalesce(date_exited_warning::date, cast('2050-12-31' as date)) 
    then 1 else 0 end as is_warning
from {{ ref('g__success__warnings__agg_snapshot_weekly') }} sw
left join {{ ref('company_metrics_merchant_info') }} msi on sw.store_id = msi.store_id
)
select
date_from as dates,
country_code as country,
origen,
cause,
count(distinct store_id) as merchants
from warnings
where is_warning = 1
group by 1,2,3,4