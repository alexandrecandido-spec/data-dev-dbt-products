{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['midmarket','daily-7am']
) }}

select
  -- colunas principais mantidas
  d.deal_id,
  d.dealstage                                      as stage,
  d.pipeline,
  d.hs_is_closed_won,
  d.last_modified_date,
  d.createdate                                     as pipeline_creation_date,
  d.dealname,
  d.hubspot_owner_id                               as deal_owner,

  -- coluna derivada de país (country)
  case
    when d.pipeline = 'Success | AR' then 'AR'
    when d.pipeline = 'Success | BR' then 'BR'
    when d.pipeline = 'Success | MX' then 'MX'
  end as country,

  -- demais colunas principais (não específicas por país)
  d.agency_that_referred,
  d.amount,
  d.associated_deal_ids,
  d.business_model_sales,
  d.cidade_territorio_sales                        as city_state_sales,
  d.close_date_sales,
  d.closed_won_notes_sales,
  d.closed_won_reason_1_upsell,
  d.closed_won_reason__1__nuevmshop_,
  d.closed_won_reason__2__nuevmshop_,
  d.closedate,
  d.company_name,
  d.competitor_identified,
  d.consider_unknown,
  d.cpt,
  d.data_go_live,
  d.deal_stage_before_closed,
  d.deal_tags,
  d.e_commerce,
  d.effective_churn_at,
  d.effective_churn_one_liner,
  d.effective_churn_root_cause,
  d.effective_churn_root_cause_2,
  d.erp,
  d.forecast,
  d.forecast_category,
  d.gmv_last_90_days_in_local_currency,
  d.gmv_potencial,
  d.go_live_forecast                              as go_live_forecast_date,
  d.hs_analytics_latest_source,
  d.hs_analytics_latest_source_data_1,
  d.hs_analytics_latest_source_data_2,
  d.hs_analytics_source,
  d.hs_analytics_source_data_1,
  d.hs_analytics_source_data_2,
  d.hubspot_team_id,
  d.kickoff_date,
  d.last_survey_answered,
  d.lead_gen_campaign_id,
  d.merged_deal_ids,
  d.need_professional_services,
  d.ne_status,
  d.notes_last_updated,
  d.not_unknown_reason,
  d.other_relevant_pains,
  d.out_of_portfolio_one_liner,
  d.out_of_portfolio_root_cause,
  d.out_of_portfolio_root_cause_2,
  d.payment_method_actual_operation,
  d.post_mortem_file_url,
  d.potential_average_ticket,
  d.potential_cvr,
  d.potential_gross_profit,
  d.potential_gross_profit_perc,
  d.potential_payback_months,
  d.potential_take_rate_perc,
  d.pre_mortem_file_url,
  d.produto_nuvemshop,
  d.responsavel_da_nuvem_pelo_fechamento_da_venda,
  d.responsavel_marketing,
  d.sales_cycle,
  d.shipping_method_actual_operation,
  d.special_condition,
  d.special_condition___reason,
  d.store_id,
  d.subscription,
  d.success_priority,
  d.top_pain_1_github_id,
  d.top_pain_1_type,
  d.top_pain_2_github_id,
  d.top_pain_2_type,
  d.type_of_onboarding,
  d.vertical,
  d.warning_summary,
  d.warning_type,
  d.where_did_the_lead_came_from_                 as acquisition_channel,

  -- colunas específicas por país (unificadas por CASE WHEN)
  case 
    when d.pipeline = 'Success | BR' then d.date_entered_downgrade_br
    when d.pipeline = 'Success | AR' then d.date_entered_downgrade_ar
    when d.pipeline = 'Success | MX' then d.date_entered_downgrade_mx
  end as date_entered_downgrade,

  case 
    when d.pipeline = 'Success | BR' then d.date_entered_effective_churn_br
    when d.pipeline = 'Success | AR' then d.date_entered_effective_churn_ar
    when d.pipeline = 'Success | MX' then d.date_entered_effective_churn_mx
    else null
  end as date_entered_effective_churn,

  case 
    when d.pipeline = 'Success | BR' then d.date_entered_warning_br
    when d.pipeline = 'Success | AR' then d.date_entered_warning_ar
    when d.pipeline = 'Success | MX' then d.date_entered_warning_mx
  end as date_entered_warning,

  case 
    when d.pipeline = 'Success | BR' then d.date_exited_warning_br
    when d.pipeline = 'Success | AR' then d.date_exited_warning_ar
    when d.pipeline = 'Success | MX' then d.date_exited_warning_mx
  end as date_exited_warning,

  case 
    when d.pipeline = 'Success | BR' then d.date_exited_effective_churn_br
    when d.pipeline = 'Success | AR' then d.date_exited_effective_churn_ar
    else null
  end as date_exited_effective_churn,

  case 
    when d.pipeline = 'Success | BR' then d.date_entered_transition_to_customer_success_onboarding__ar
    when d.pipeline = 'Success | AR' then d.date_entered_transition_to_customer_success_onboarding__ar
    else null
  end as date_entered_transition_to_customer_success_onboarding,

  -- campos de auditoria
  current_timestamp AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

from {{ ref('_int_midmarket__pipeline_success') }} d;