{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['daily-7am']
) }}

--Renewal Aquarium
with 
	--Last renewal deal
	last_renewal_deal as
        (select 
            d.store_id,
            max(d.pipeline_creation_date) as last_date
        from {{ ref('s__upsell__renewal__pipeline__snapshot') }} d 
        where 
            d.store_id > 0
            and d.client_upsell_motive = 'Renewal'
        group by 1),
    renewal_deal as
        (select distinct
            d.store_id,
            d.deal_id as renewal_deal_id,
            d.stage as renewal_stage,
            d.deal_owner as renewal_deal_owner
        from {{ ref('s__upsell__renewal__pipeline__snapshot') }} d 
            inner join last_renewal_deal lrd
                on d.store_id = lrd.store_id
                and d.pipeline_creation_date = lrd.last_date
        where 
            d.store_id > 0 
            and d.client_upsell_motive = 'Renewal')
select distinct 
	d.store_id,
	d.deal_id as success_deal_id,
    d.country,
    d.dealname,
    d.deal_owner as success_deal_owner,
	d.stage as success_deal_stage,
	cast(d.pipeline_creation_date as date) as pipeline_creation_date,
	cast(d.closedate as date) as closedate,
	cast(d.kickoff_date as date) as kick_off_date,
    d.gmv_potencial as potential_gmv,
	d.potential_gross_profit_perc, 
    d.potential_gross_profit,
    d.subscription,
	d.cpt,
	d.success_priority,
    --Renewal info
    rd.renewal_deal_id,
    coalesce(rd.renewal_stage, 'Not contacted') as renewal_deal_stage,
    rd.renewal_deal_owner,
    --Store data
    mi.store_name,
    mi.domain,
    mi.store_creation_date,
    mi.current_plan,
    mi.store_churn_date,
    mi.vertical,
    mi.franchise_group,
    c.contract_end_date,
    --Finance data
    fd.last_finance_month,
    fd.last_month_segment,
    fd.gmv_usd_last_month,
    fd.gmv_last_month,
    fd.orders_on_platform_last_month,
    fd.gmv_usd_six_months_avg,
    fd.gmv_six_months_avg,
    fd.orders_on_platform_six_months_avg,
    fd.gmv_usd_three_months_avg,
    fd.gmv_three_months_avg,
    fd.orders_on_platform_three_months_avg,
    current_timestamp as sys_audit_created_on,
    'data-dev-dbt-products' as sys_audit_created_by,
    current_timestamp as sys_audit_updated_on,
    'data-dev-dbt-products' as sys_audit_updated_by
from {{ ref('s__success__pipeline__snapshot') }} d
    left join {{ ref('_int__midmarket__upsell_and_renewal_merchant_info') }} mi
        on d.store_id = mi.store_id
    left join {{ ref('_int__midmarket__upsell_and_renewal_financial_data') }} fd
        on d.store_id = fd.store_id
    left join {{ ref('_int_midmarket_wbr_mbr__companies') }} c
        on d.store_id = c.store_id
    left join renewal_deal as rd
		on d.store_id = rd.store_id
where 
	d.stage not in ('Out of portfolio','Effective churn')