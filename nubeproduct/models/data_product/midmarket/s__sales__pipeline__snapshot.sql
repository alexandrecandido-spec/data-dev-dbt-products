{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['midmarket','daily-7am']
) }}

select
  -- colunas originais mantidas até hubspot_owner_id
  d.deal_id,
  d.dealstage                              as stage,
  d.pipeline,
  d.hs_is_closed_won,
  d.last_modified_date,
  d.createdate                             as pipeline_creation_date,
  d.dealname,
  d.hubspot_owner_id                       as deal_owner,

  -- coluna derivada de país (country)
  case
    when d.pipeline = 'Sales | AR' then 'AR'
    when d.pipeline = 'Sales | BR' then 'BR'
    when d.pipeline = 'Sales | MX' then 'MX'
  end as country,

  -- demais colunas (exceto as específicas por país) -> somente as que existem no staging
  d.agency_that_referred,
  d.amount,
  d.area_de_interesse,
  d.associated_deal_ids,
  d.business_model_sales,
  d.cidade_territorio_sales                as city_state_sales,
  d.client_upsell_motive,
  d.closed_lost_notes_sales,
  d.closed_lost_reason__1__nuevmshop_,
  d.closed_lost_reason__2__nuevmshop_,
  d.closedate,
  d.company_name,
  d.cpt,
  d.deal_stage_before_closed,
  d.deal_tags,
  d.decision_maker_contact_source,
  d.e_commerce,
  d.erp,
  d.forecast,
  d.forecast_category,
  d.gmv_last_90_days_in_local_currency,
  d.gmv_potencial,
  d.go_live_forecast                       as go_live_forecast_date,
  d.hs_analytics_latest_source,
  d.hs_analytics_latest_source_data_1,
  d.hs_analytics_latest_source_data_2,
  d.hs_analytics_source,
  d.hs_analytics_source_data_1,
  d.hs_analytics_source_data_2,
  d.hubspot_team_id,
  d.last_survey_answered,
  d.lead_gen_campaign_id,
  d.merged_deal_ids,
  d.ne_status,
  d.non_conversion_reason_ne_discovery,
  d.non_conversion_sub_reason_ne_discovery,
  d.notes_last_updated,
  d.outbound_lead_gen_score_deal,
  d.payment_method_actual_operation,
  d.platform,
  d.potential_average_ticket,
  d.potential_cvr,
  d.potential_gross_profit,
  d.potential_gross_profit_perc,
  d.potential_payback_months,
  d.potential_take_rate_perc,
  d.problem_description,
  d.produto_nuvemshop,
  d.responsavel_da_nuvem_pelo_fechamento_da_venda,
  d.responsavel_marketing,
  d.sales_cycle,
  d.segmento_nuvemshop,
  d.shipping_method_actual_operation,
  d.stage_before_closing_deal,
  d.store_id,
  d.subcategory,
  d.subscription,
  d.success_priority,
  d.type_of_onboarding,
  d.vertical,
  d.where_did_the_lead_came_from_          as acquisition_channel,
  d.need_professional_services,

  -- colunas adicionais não-sufixadas que existem no staging
  d.closed_won_reason__1__nuevmshop_,
  d.closed_won_reason__2__nuevmshop_,
  d.closed_won_notes_sales,
  d.cross_sell,
  d.contract_end_date,
  d.macro_motivo_de_perda___np,
  d.micro_motivo_de_perda_np,
  d.forecast_lider_judgement,
  d.special_condition,
  d.special_condition___reason,
  d.lead_source_ne,
  d.no_show_date,
  d.close_date_sales,
  d.competitor_identified,
  d.lead_channel,
  d.segmento_ne,
  d.freight_calculation,

  -- colunas genéricas unificadas por país (apenas usando colunas que existem no staging)

  -- LEADS/MQLs - entered (staging só possui BR)
  case 
    when d.pipeline = 'Sales | BR' then d.date_entered_leads_mqls_br
    else null
  end as date_entered_leads_mqls,

  -- LEADS/MQLs - exited (staging só possui BR)
  case 
    when d.pipeline = 'Sales | BR' then d.date_exited_leads_mqls_br
    else null
  end as date_exited_leads_mqls,

  -- PROBLEM DISCOVERY (Sales Dev) - AR/BR/MX existem no staging
  case 
    when d.pipeline = 'Sales | BR' then d.date_entered_problem_discovery_sales_dev_br
    when d.pipeline = 'Sales | AR' then d.date_entered_problem_discovery_sales_dev_ar
    when d.pipeline = 'Sales | MX' then d.date_entered_problem_discovery_sales_dev_mx
  end as date_entered_problem_discovery_sales_dev,

  -- PROBLEM DISCOVERY (genérico) - BR/AR/MX existem no staging
  case 
    when d.pipeline = 'Sales | BR' then d.date_entered_problem_discovery_br
    when d.pipeline = 'Sales | AR' then d.date_entered_problem_discovery_ar
    when d.pipeline = 'Sales | MX' then d.date_entered_problem_discovery_mx
  end as date_entered_problem_discovery,

  -- PROBLEM DISCOVERY - exited (staging tem BR e AR)
  case 
    when d.pipeline = 'Sales | BR' then d.date_exited_problem_discovery_br
    when d.pipeline = 'Sales | AR' then d.date_exited_problem_discovery_ar
    else null
  end as date_exited_problem_discovery,

  -- SCHEDULED OPPORTUNITIES (genérico) - BR/AR/MX existem no staging
  case 
    when d.pipeline = 'Sales | BR' then d.date_entered_scheduled_opportunities_br
    when d.pipeline = 'Sales | AR' then d.date_entered_scheduled_opportunities_ar
    when d.pipeline = 'Sales | MX' then d.date_entered_scheduled_opportunities_mx
  end as date_entered_scheduled_opportunities,

  -- SCHEDULED OPPORTUNITIES (Sales) - staging tem AR e MX (BR não existe)
  case 
    when d.pipeline = 'Sales | AR' then d.date_entered_scheduled_opportunities_sales_ar
    when d.pipeline = 'Sales | MX' then d.date_entered_scheduled_opportunities_sales_mx
    else null
  end as date_entered_scheduled_opportunities_sales,

  -- PROSPECT MKT - entered (staging tem BR e AR)
  case 
    when d.pipeline = 'Sales | BR' then d.date_entered_prospect_mkt_br
    when d.pipeline = 'Sales | AR' then d.date_entered_prospect_mkt_ar
    else null
  end as date_entered_prospect_mkt,

  -- PROSPECT MKT - exited (staging tem BR e AR)
  case 
    when d.pipeline = 'Sales | BR' then d.date_exited_prospect_mkt_br
    when d.pipeline = 'Sales | AR' then d.date_exited_prospect_mkt_ar
    else null
  end as date_exited_prospect_mkt,

  -- LOST - entered (staging tem BR/AR/MX)
  case 
    when d.pipeline = 'Sales | BR' then d.date_entered_lost_br
    when d.pipeline = 'Sales | AR' then d.date_entered_lost_ar
    when d.pipeline = 'Sales | MX' then d.date_entered_lost_mx
  end as date_entered_lost,

  -- WON - entered (staging tem BR/AR/MX)
  case 
    when d.pipeline = 'Sales | BR' then d.date_entered_won_br
    when d.pipeline = 'Sales | AR' then d.date_entered_won_ar
    when d.pipeline = 'Sales | MX' then d.date_entered_won_mx
  end as date_entered_won,

  -- OPEN NE DISCOVERY - entered (staging só tem BR)
  case 
    when d.pipeline = 'Sales | BR' then d.date_entered_open_ne_discovery_br
    else null
  end as date_entered_open_ne_discovery,

  -- campos de auditoria
  current_timestamp AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

from {{ ref('_int_midmarket__pipeline_sales') }} d;