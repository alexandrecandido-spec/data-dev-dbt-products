select
    d.store_id,
    d.pipeline,
    d.deal_id,
    d.dealname,
    d.gmv_potencial,
    d.hubspot_owner_id,
    d.dealstage,
    d.createdate,
    d.kickoff_date,
    d.go_live_forecast,
    d.data_go_live,
    d.effective_churn_at,
    d.date_entered_churn_onboarding_ar,
    d.date_entered_churn_onboarding_br,
    d.date_entered_churn_onboarding_mx,
    d.date_entered_downgrade_onboarding_ar,
    d.date_entered_downgrade_onboarding_br,
    d.date_entered_downgrade_onboarding_mx,
    d.effective_out_of_portfolio_at,
    d.deadline_goal,
    d.forecast,
    d.delay_reason,
    d.need_professional_services,
    d.type_of_onboarding,
    d.payment_method_actual_operation,
    d.shipping_method_actual_operation,
    d.erp,
    d.e_commerce,
    d.where_did_the_lead_came_from_,
    d.cidade_territorio_sales,
    d.vertical,
    
    CASE WHEN d.data_go_live IS NOT NULL
      THEN DATEDIFF(d.data_go_live, d.kickoff_date)
    END AS lead_time_days,

    CASE WHEN d.dealstage IN ('Project development','Pre-churn','Pre Go Live','Go Live','Warning')
           AND d.data_go_live IS NULL
      THEN DATEDIFF(current_date(), d.kickoff_date)
    END AS on_going_lead_time_days

  FROM {{ ref('midmarket__general__deals__link') }} d
  LEFT JOIN {{ ref('midmarket_hubspot_deleted_deals') }}  dd
    ON cast(dd.deal_id as bigint) = d.deal_id
  WHERE dd.deal_id IS NULL
    AND d.pipeline IN ('Onboarding | AR','Onboarding | BR','Onboarding | MX')