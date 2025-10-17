{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['daily-6am']
) }}

select distinct
  deal_id,
  store_id,
  
  case
    when pipeline = 'Onboarding | AR' then 'AR'
    when pipeline = 'Onboarding | BR' then 'BR'
    when pipeline = 'Onboarding | MX' then 'MX'
  end                                    as country,

  pipeline,
  dealname,
  gmv_potencial,
  hubspot_owner_id                       as deal_owner,
  dealstage                              as stage,

  /* estado del deal (negocio) */
  case
    when (dealstage = 'Transition to Customer Success' or data_go_live is not null) then 'completed'
    when dealstage in ('Churn','Downgrade de plano','Downgrade de plan')            then 'lost'
    when lower(dealstage) like '%paused by merchant%'                                then 'paused'
    when dealstage in ('Kick off','Pre-analysis')                                    then 'pre kick-off'
    when dealstage in ('Project development','Pre-churn','Pre Go Live','Go Live','Warning') then 'on-going'
  end                                    as deal_status,

  /* fechas renombradas */
  createdate                             as pipeline_creation_date,
  kickoff_date                           as kick_off_date,
  go_live_forecast                       as go_live_forecast_date,
  data_go_live                           as go_live_real_date,

  /* churn / downgrade derivadas (negocio) */
  case when dealstage = 'Churn'
    then cast(coalesce(date_entered_churn_onboarding_ar, date_entered_churn_onboarding_br, date_entered_churn_onboarding_mx) as date)
  end                                    as churn_date,

  effective_churn_at,

  case when dealstage in ('Downgrade de plano','Downgrade de plan')
    then cast(coalesce(date_entered_downgrade_onboarding_ar, date_entered_downgrade_onboarding_br, date_entered_downgrade_onboarding_mx) as date)
  end                                    as downgrade_date,

  effective_out_of_portfolio_at,

  /* lead times (calculados en intermediate) */
  lead_time_days                         as lead_time,
  on_going_lead_time_days                as on_going_lead_time,

  /* deadline_goal numérico (negocio) */
  case
    when deadline_goal in (
      '15 days','20 days','25 days','30 days','35 days','40 days','45 days',
      '50 days','55 days','60 days','75 days','90 days','105 days','120 days'
    )
    then cast(substring(deadline_goal, 1, instr(deadline_goal,'days') - 2) as int)
  end                                    as deadline_goal,

  deadline_goal                          as original_deadline_goal,

  /* normalizaciones finales */
  delay_reason,
  case lower(need_professional_services)
    when 'yes' then true
    when 'no'  then false
    else null
  end                                    as need_professional_services,

  type_of_onboarding,
  payment_method_actual_operation,
  shipping_method_actual_operation,
  erp,
  e_commerce,
  where_did_the_lead_came_from_          as acquisition_channel,
  vertical,
  cidade_territorio_sales                as city_state_sales,

  current_timestamp AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

from {{ ref('_int_midmarket__pipeline_onboarding') }}
;