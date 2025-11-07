{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['midmarket','daily-7am']
) }}

select
    d.deal_id,
    d.store_id,
    d.dealstage as stage,
    case
        when d.dealstage in ('Suspect','Prospect','Scheduled Meeting','Negotiation','In Signature') then 'On-going'
        when d.dealstage = 'Lost' then 'Lost'
        when d.dealstage in ('Won','Upsell','NEXT Renewal') then 'Won'
    end as deal_status,
    d.dealname,
    d.hubspot_owner_id as deal_owner,
    d.responsavel_marketing as sales_dev_owner,
    cast(d.createdate as timestamp) as pipeline_creation_date,
    cast(d.closedate as timestamp) as closedate,
    case
        when d.pipeline = 'Upsell Success | AR' then 'AR'
        when d.pipeline = 'Upsell Success | BR' then 'BR'
        when d.pipeline = 'Upsell Success | MX' then 'MX'
        else null
    end as country,
    d.pipeline,
    d.client_upsell_motive,
    d.gmv_potencial as potential_gmv,
    d.potential_gross_profit_perc, 
    d.potential_gross_profit,
    d.subscription,
    d.cpt,
    d.success_priority,
    d.vertical,
    d.closed_lost_reason__1__nuevmshop_ as closed_lost_reason_1,
    d.closed_lost_reason__2__nuevmshop_ as closed_lost_reason_2,
    d.closed_won_reason__1__nuevmshop_ as closed_won_reason_1,
    d.closed_won_reason__2__nuevmshop_ as closed_won_reason_2,
    d.closed_lost_notes_sales,
    d.notes_last_updated,
    d.company_name,
    case 
        when d.pipeline = 'Upsell Success | AR' then cast(d.date_entered_negotiation_upsell_success_ar as timestamp)
        when d.pipeline = 'Upsell Success | BR' then cast(d.date_entered_negotiation_upsell_success_br as timestamp)
        when d.pipeline = 'Upsell Success | MX' then null
        else null
    end as date_entered_negotiation_upsell_success,
    d.forecast_category,
    d.stage_before_closing_deal,
    d.cidade_territorio_sales as city_state_sales,
    d.deal_tags,
    case 
        when d.deal_tags like '%Aspirational brand%' then 1 else 0 
    end as aspirational_brand,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from {{ ref('_int_midmarket__pipeline_upsell_renewal') }} as d