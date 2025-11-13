{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['midmarket','daily-7am']
) }}

select distinct 
    d.store_id,
    d.deal_id,
    d.country,
    d.company_name,
    d.dealname,
    d.deal_owner,
    d.stage,
    d.deal_status,
    d.client_upsell_motive as client_bucket,
    d.potential_gmv,
    d.potential_gross_profit_perc, 
    d.potential_gross_profit,
    c.contract_end_date,
    d.pipeline_creation_date,
    d.closedate,
    d.date_entered_negotiation_upsell_success,
    d.success_priority,
    d.subscription,
    d.cpt,
    d.acquisition_channel,
    d.forecast_category,
    d.stage_before_closing_deal,
    d.closed_lost_reason_1,
    d.closed_lost_reason_2,
    d.closed_won_reason_1,
    d.closed_won_reason_2,
    d.city_state_sales,
    d.aspirational_brand,
    --Store data
    mi.store_name,
    mi.domain,
    mi.store_creation_date,
    mi.current_plan,
    mi.first_payment,
    mi.store_churn_date,
    mi.vertical,
    mi.franchise_group,
    --Financial data
    fd.last_finance_month,
    fd.last_month_segment,
    fd.gmv_usd_last_month,
    fd.gmv_last_month,
    fd.gmv_usd_on_platform_last_month,
    fd.gmv_on_platform_last_month,
    fd.orders_on_platform_last_month,
    fd.gmv_usd_six_months_avg,
    fd.gmv_six_months_avg,
    fd.gmv_usd_on_platform_six_months_avg,
    fd.gmv_on_platform_six_months_avg,
    fd.orders_on_platform_six_months_avg,
    fd.gmv_usd_three_months_avg,
    fd.gmv_three_months_avg,
    fd.gmv_usd_on_platform_three_months_avg,
    fd.gmv_on_platform_three_months_avg,
    fd.orders_on_platform_three_months_avg,
    current_timestamp as sys_audit_created_on,
    'data-dev-dbt-products' as sys_audit_created_by,
    current_timestamp as sys_audit_updated_on,
    'data-dev-dbt-products' as sys_audit_updated_by
from {{ ref('s__upsell__renewal__pipeline__snapshot') }} d
    left join {{ ref('_int__midmarket__upsell_and_renewal_merchant_info') }} mi
        on d.store_id = mi.store_id
    left join {{ ref('_int__midmarket__upsell_and_renewal_financial_data') }} fd
        on d.store_id = fd.store_id
    left join {{ ref('_int_midmarket_wbr_mbr__companies') }} c
        on d.store_id = c.store_id