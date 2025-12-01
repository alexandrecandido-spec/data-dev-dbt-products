{{ config(
    materialized='table',
    tags=['midmarket','daily-6am']
) }}

select distinct
	store_id,
	deal_id,
    createdate,
	dealname,
    pipeline,
    regexp_extract(pipeline, '\\|\\s*([A-Z]{2})$', 1) as country,
    cast(date_trunc('month',closedate) as date) as close_month,
    cast(date_trunc('week',closedate) as date) as close_week,
    cast(date_trunc('month', close_date_sales) as date) as sales_close_month,
    cast(date_trunc('week', close_date_sales) as date) as sales_close_week,
	where_did_the_lead_came_from_ as acquisition_channel,
	vertical as hubspot_vertical,
	gmv_potencial as potential_gmv,
	subscription,
    cpt,
    potential_gross_profit_perc,
	dealstage,
    produto_nuvemshop,
    hubspot_owner_id as owner,
    --Start sales information
        cast(date_trunc(
            'month',
            case pipeline 
                when 'Sales | AR' then date_entered_scheduled_opportunities_sales_ar
                when 'Sales | BR' then date_entered_scheduled_opportunity_br
                when 'Sales | MX' then date_entered_scheduled_opportunities_sales_mx
            end) as date) as sales_date_entered_scheduled_meetings_month,
        cast(date_trunc(
            'week',
            case pipeline 
                when 'Sales | AR' then date_entered_scheduled_opportunities_sales_ar
                when 'Sales | BR' then date_entered_scheduled_opportunity_br
                when 'Sales | MX' then date_entered_scheduled_opportunities_sales_mx
            end) as date) as sales_date_entered_scheduled_meetings_week,
        cast(date_trunc(
            'month',
            case pipeline 
                when 'Sales | AR' then date_entered_problem_discovery_ar
                when 'Sales | BR' then date_entered_problem_discovery_br
                when 'Sales | MX' then date_entered_problem_discovery_mx
            end) as date) as sales_date_entered_problem_discovery_month,
        cast(date_trunc(
            'week',
            case pipeline 
                when 'Sales | AR' then date_entered_problem_discovery_ar
                when 'Sales | BR' then date_entered_problem_discovery_br
                when 'Sales | MX' then date_entered_problem_discovery_mx
            end) as date) as sales_date_entered_problem_discovery_week,
        amount,
        segmento_nuvemshop,
        cidade_territorio_sales,
    --End sales information
    --Start upsell information
        client_upsell_motive,
    --End upsell information
    --Start onboarding information
        cast(date_trunc('month', closedate) as date) as onboarding_close_month,
        cast(date_trunc('week', closedate) as date) as onboarding_close_week,
        cast(date_trunc('month', kickoff_date) as date) as onboarding_project_start_month,
        cast(date_trunc('week', kickoff_date) as date) as onboarding_project_start_week,
        cast(date_trunc(
            'month', 
            case pipeline
                when 'Onboarding | AR' then d.date_entered_transition_to_customer_success_onboarding__ar
                when 'Onboarding | BR' then d.date_entered_transition_to_customer_success_onboarding__br
                --when 'Onboarding | MX' then d.date_entered_transition_to_customer_success_onboarding__mx
            end) as date) as onboarding_transition_to_customer_success_month,
        cast(date_trunc(
            'week', 
            case pipeline
                when 'Onboarding | AR' then d.date_entered_transition_to_customer_success_onboarding__ar
                when 'Onboarding | BR' then d.date_entered_transition_to_customer_success_onboarding__br
                --when 'Onboarding | MX' then d.date_entered_transition_to_customer_success_onboarding__mx
            end) as date) as onboarding_transition_to_customer_success_week,
        cast(date_trunc(
            'month', 
            case pipeline
                when 'Onboarding | AR' then d.date_entered_churn_onboarding_ar
                when 'Onboarding | BR' then d.date_entered_churn_onboarding_br
                when 'Onboarding | MX' then d.date_entered_churn_onboarding_mx
            end) as date) as onboarding_churn_month,
        cast(date_trunc(
            'week', 
            case pipeline
                when 'Onboarding | AR' then d.date_entered_churn_onboarding_ar
                when 'Onboarding | BR' then d.date_entered_churn_onboarding_br
                when 'Onboarding | MX' then d.date_entered_churn_onboarding_mx
            end) as date) as onboarding_churn_week,
        cast(date_trunc(
            'month', 
            case pipeline
                when 'Onboarding | AR' then d.date_entered_downgrade_onboarding_ar
                when 'Onboarding | BR' then d.date_entered_downgrade_onboarding_br 
                when 'Onboarding | MX' then d.date_entered_downgrade_onboarding_mx 
            end) as date) as onboarding_downgrade_month,
        cast(date_trunc(
            'week', 
            case pipeline
                when 'Onboarding | AR' then d.date_entered_downgrade_onboarding_ar
                when 'Onboarding | BR' then d.date_entered_downgrade_onboarding_br 
                when 'Onboarding | MX' then d.date_entered_downgrade_onboarding_mx 
            end) as date) as onboarding_downgrade_week,
        date_trunc('month', cast(data_go_live as date)) as onboarding_go_live_month,
        date_trunc('week', cast(data_go_live as date)) as onboarding_go_live_week,
    --End onboarding information
    --Start success information
        --Start churn information
        case pipeline 
            when 'Success | AR' then date_entered_effective_churn_ar
            when 'Success | BR' then date_entered_effective_churn_br
            when 'Success | MX' then date_entered_effective_churn_mx
        end date_churn,
        cast(date_trunc(
            'month',
            case pipeline 
                when 'Success | AR' then date_entered_effective_churn_ar
                when 'Success | BR' then date_entered_effective_churn_br
                when 'Success | MX' then date_entered_effective_churn_mx
            end) as date) as churn_month,
        cast(date_trunc(
            'week',
            case pipeline 
                when 'Success | AR' then date_entered_effective_churn_ar
                when 'Success | BR' then date_entered_effective_churn_br
                when 'Success | MX' then date_entered_effective_churn_mx
            end) as date) as churn_week,
        d.effective_churn_root_cause,
        --End churn information
        --Start out of portfolio information
        case pipeline 
            when 'Success | AR' then date_entered_downgrade_ar
            when 'Success | BR' then date_entered_downgrade_br
            when 'Success | MX' then date_entered_downgrade_mx
        end date_out_of_portfolio,
        cast(date_trunc(
            'month',
            case pipeline 
                when 'Success | AR' then date_entered_downgrade_ar
                when 'Success | BR' then date_entered_downgrade_br
                when 'Success | MX' then date_entered_downgrade_mx
            end) as date) as out_of_portfolio_month,
        cast(date_trunc(
            'week',
            case pipeline 
                when 'Success | AR' then date_entered_downgrade_ar
                when 'Success | BR' then date_entered_downgrade_br
                when 'Success | MX' then date_entered_downgrade_mx
            end) as date) as out_of_portfolio_week,
        out_of_portfolio_root_cause,
        --End out of portfolio information
    --End success information
    current_timestamp AS sys_audit_created_on,
	'data-dev-dbt-products' AS sys_audit_created_by,
	current_timestamp AS sys_audit_updated_on,
	'data-dev-dbt-products' AS sys_audit_updated_by
from {{ source('stg_third_party', 'midmarket_hubspot_deals') }} as d
where
	pipeline in
        ('Sales | AR',
        'Sales | BR',
        'Sales | MX',
        'Upsell Success | AR',
        'Upsell Success | BR',
        'Upsell Success | MX',
        'Onboarding | AR',
        'Onboarding | BR',
        'Onboarding | MX',
        'Success | AR',
        'Success | BR',
        'Success | MX'
    )
    and deal_id not in (select deal_id from {{ ref('midmarket_hubspot_deleted_deals') }})