{{ config(
    materialized='table',
    tags=['operations','daily-6am']
) }}

select
    store_id,
    deal_id,
    dealname,
    case pipeline 
        when 'Success | AR' then 'AR'
        when 'Success | BR' then 'BR'
        when 'Success | MX' then 'MX'
    end country,
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
    d.effective_churn_root_cause,
    d.where_did_the_lead_came_from_ as acquisition_channel,
    d.vertical as hubspot_vertical,
    d.gmv_potencial as potential_gmv,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from {{ source('stg_third_party', 'midmarket_hubspot_deals') }} as d
    where 
        pipeline in 
            (
            'Success | AR',
            'Success | BR',
            'Success | MX'
            )
        and dealstage = 'Effective churn'