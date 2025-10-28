{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'], 
    tags=['midmarket','daily-6am']
) }}

select
  cast(deal_id as bigint)                           as deal_id,
  store_id,
  pipeline,
  dealname,
  gmv_potencial,
  hubspot_owner_id,
  dealstage,
  cast(createdate as date)                           as createdate,
  cast(kickoff_date as date)                         as kickoff_date,
  cast(go_live_forecast as date)                     as go_live_forecast,
  cast(data_go_live as date)                         as data_go_live,
  cast(effective_churn_at as date)                   as effective_churn_at,
  cast(effective_out_of_portfolio_at as date)        as effective_out_of_portfolio_at,
  date_entered_churn_onboarding_ar,
  date_entered_churn_onboarding_br,
  date_entered_churn_onboarding_mx,  
  date_entered_downgrade_onboarding_ar,
  date_entered_downgrade_onboarding_br,
  date_entered_downgrade_onboarding_mx,  
  deadline_goal,
  forecast,
  delay_reason,
  need_professional_services,
  type_of_onboarding,
  payment_method_actual_operation,
  shipping_method_actual_operation,
  erp,
  e_commerce,
  where_did_the_lead_came_from_,
  cidade_territorio_sales,
  vertical,

  nullif(associated_deal_ids, '')                   as associated_deal_ids,

  current_timestamp AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

from {{ source('stg_third_party','midmarket_hubspot_deals') }}