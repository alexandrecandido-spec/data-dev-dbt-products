WITH gmv AS (
    SELECT
        store_id,
        round(avg(gmv_usd_monthly),2) AS avg_gmv_usd_last_3m,
        round(avg(orders_monthly)) AS avg_orders_last_3m,
        MAX(sys_audit_updated_on) AS gmv_max_sys_audit_updated_on
    FROM {{ref('company_metrics_gmv_and_segments')}}
    WHERE trunc(datemonth, 'MM') BETWEEN add_months(trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM'),-2)
        AND trunc((SELECT max(datemonth) FROM {{ref('company_metrics_gmv_and_segments')}}), 'MM')
    GROUP BY 1)

select
nc_data.*,
 CASE 
    WHEN nc_data.current_invoice_state = 'paid' AND (nc_data.ai_conversations_after_invoice > 0 OR nc_data.days_since_last_invoice <= 10) THEN 'paying'
    WHEN nc_data.current_invoice_state = 'paid' AND coalesce(nc_data.ai_conversations_after_invoice, 0) = 0 AND nc_data.days_since_last_invoice > 10 THEN 'paid churned'
    WHEN nc_data.onboarding = false AND coalesce(nc_data.total_invoices, 0) = 0 AND (nc_data.trial_end_date < current_date OR nc_data.trial_end_date is NULL) AND (coalesce(nc_data.conversations_after_trial, 0) = 0 OR nc_data.last_conversation_date <= DATE('2025-07-31')) THEN 'not converted'
    WHEN nc_data.onboarding = false AND coalesce(nc_data.total_invoices, 0) = 0 AND (nc_data.trial_end_date >= date_sub(current_date, 30) OR nc_data.trial_start_date >= date_sub(current_date, 45)) AND nc_data.cycle_end_date >= current_date AND nc_data.conversations_after_trial > 0 THEN 'post trial pre invoice'
    WHEN nc_data.current_invoice_state = 'unpaid' AND coalesce(nc_data.paid_invoices, 0) = 0 AND current_date<=grace_until THEN 'first grace period'
    WHEN nc_data.current_invoice_state = 'unpaid' AND nc_data.paid_invoices > 0 AND current_date<=grace_until AND unpaid_invoices_since_last_paid=1 THEN 'grace period'
    WHEN nc_data.current_invoice_state = 'unpaid' AND  (current_date>grace_until OR unpaid_invoices_since_last_paid>1) AND nc_data.paid_invoices > 0 THEN 'overdue churned'
    WHEN nc_data.current_invoice_state = 'unpaid' AND  current_date>grace_until AND coalesce(nc_data.paid_invoices, 0) = 0 THEN 'overdue not converted'
    WHEN nc_data.trial_end_date >= current_date THEN 'on trial'
    WHEN coalesce(nc_data.total_invoices, 0) = 0 AND coalesce(nc_data.conversations_after_trial, 0) > 0 AND (((nc_data.trial_end_date < current_date OR nc_data.trial_end_date is NULL) AND nc_data.cycle_end_date < current_date) 
        OR (nc_data.onboarding = false AND (nc_data.trial_end_date < date_sub(current_date, 30) OR nc_data.trial_start_date < date_sub(current_date, 45)) AND nc_data.cycle_end_date >= current_date))
        THEN 'issues'
    WHEN nc_data.store_id IS NOT NULL AND nc_data.onboarding = false THEN 'issues'
    WHEN nc_data.onboarding = true THEN 'onboarding'
ELSE 'issues' END AS chatnube_state,
 CASE 
    WHEN nc_data.current_invoice_state = 'paid' AND (nc_data.ai_conversations_after_invoice > 0 OR nc_data.days_since_last_invoice <= 10)  THEN 'on track'
    WHEN nc_data.current_invoice_state = 'paid' AND coalesce(nc_data.ai_conversations_after_invoice, 0) = 0  AND nc_data.days_since_last_invoice > 10 THEN 'churn'
    WHEN nc_data.onboarding = false AND coalesce(nc_data.total_invoices, 0) = 0 AND (nc_data.trial_end_date < current_date OR nc_data.trial_end_date is NULL) AND (coalesce(nc_data.conversations_after_trial, 0) = 0 OR nc_data.last_conversation_date <= DATE('2025-07-31')) THEN 'not converted'
    WHEN nc_data.onboarding = false AND coalesce(nc_data.total_invoices, 0) = 0 AND (nc_data.trial_end_date >= date_sub(current_date, 30) OR nc_data.trial_start_date >= date_sub(current_date, 45)) AND nc_data.cycle_end_date >= current_date AND nc_data.conversations_after_trial > 0 THEN 'on track'
    WHEN nc_data.current_invoice_state = 'unpaid' AND coalesce(nc_data.paid_invoices, 0) = 0 AND current_date<=grace_until THEN 'on track'
    WHEN nc_data.current_invoice_state = 'unpaid' AND nc_data.paid_invoices > 0 AND current_date<=grace_until AND unpaid_invoices_since_last_paid=1 THEN 'on track'
    WHEN nc_data.current_invoice_state = 'unpaid' AND (current_date>grace_until OR unpaid_invoices_since_last_paid>1 ) AND nc_data.paid_invoices > 0 THEN 'churn'
    WHEN nc_data.current_invoice_state = 'unpaid' AND current_date>grace_until AND coalesce(nc_data.paid_invoices, 0) = 0 THEN 'not converted'
    WHEN nc_data.trial_end_date >= current_date THEN 'trial'
    WHEN coalesce(nc_data.total_invoices, 0) = 0 AND coalesce(nc_data.conversations_after_trial, 0) > 0 AND (((nc_data.trial_end_date < current_date OR nc_data.trial_end_date is NULL) AND nc_data.cycle_end_date < current_date) 
        OR (nc_data.onboarding = false AND (nc_data.trial_end_date < date_sub(current_date, 30) OR nc_data.trial_start_date < date_sub(current_date, 45)) AND nc_data.cycle_end_date >= current_date))
        THEN 'issues'
    WHEN nc_data.store_id IS NOT NULL AND nc_data.onboarding = false THEN 'issues'
    WHEN nc_data.onboarding = true THEN 'activation'
ELSE 'issues' END AS chatnube_state_group,
 CASE
  WHEN nc_data.current_invoice_state = 'paid' AND coalesce(nc_data.ai_conversations_after_invoice, 0) = 0 AND nc_data.days_since_last_invoice > 10 THEN date_add(nc_data.invoice_created_at, 11)
  WHEN nc_data.current_invoice_state = 'unpaid' AND (current_date>grace_until OR unpaid_invoices_since_last_paid>1) AND nc_data.paid_invoices > 0 THEN date_add(nc_data.invoice_created_at, 11)
  ELSE NULL END AS churned_date,
msi.country,
gp.grupo AS plan_group,
msi.domain,
msi.state,
 CASE
  WHEN msi.state = 0 THEN '0 - store ok'
  WHEN msi.state = 1 THEN '1 - awaiting store payment'
  WHEN msi.state = 2 THEN '2 - store admin down'
  WHEN msi.state = 3 THEN '3 - store churned'
  WHEN msi.state = 4 THEN '4 - test store'
  WHEN msi.state = 5 THEN '5 - store on partner prep'
END AS tiendanube_state,
msi.current_segment,
gmv.avg_gmv_usd_last_3m,
gmv.avg_orders_last_3m,
GREATEST(
    max(nc_data.max_sys_audit_updated_on),
    max(msi.sys_audit_updated_on),
    max(gmv.gmv_max_sys_audit_updated_on),
    max(gp.sys_audit_updated_on)
) as max_combined_sys_audit_updated_on
FROM {{ref('_int_product__nuvemchat_stores_trial_chats_invoices')}} nc_data
JOIN {{ref('moltres__mwp_store_info')}} msi ON nc_data.store_id = msi.store_id
LEFT JOIN {{ref('operations_grouping_plans')}} gp ON gp.plan = msi.plan
LEFT JOIN gmv ON gmv.store_id = nc_data.store_id
WHERE nc_data.store_id <> 1234 AND msi.state NOT IN (3,4)
GROUP BY 
    nc_data.store_id,
    nc_data.cn_store_id,
    nc_data.cn_merchant_name,
    nc_data.onboarding,
    nc_data.installed_at,
    nc_data.trial_start_date,
    nc_data.trial_end_date,
    nc_data.cycle_start_date,
    nc_data.cycle_end_date,
    nc_data.last_invoice_id,
    nc_data.invoice_created_at,
    nc_data.invoice_start_cycle_date,
    nc_data.invoice_end_cycle_date,
    nc_data.days_since_last_invoice,
    nc_data.last_invoice_count_conversation,
    nc_data.paid_invoices,
    nc_data.last_paid_date,
    nc_data.first_paid_date,
    nc_data.grace_until,
    nc_data.overall_grace_until,
    nc_data.current_invoice_state,
    nc_data.total_invoices,
    nc_data.unpaid_invoices_since_last_paid,
    nc_data.ai_conversations_after_invoice,
    nc_data.conversations_after_trial,
    nc_data.conversations_in_trial,
    nc_data.ai_conv_last_3d,
    nc_data.last_conversation_date,
    nc_data.max_sys_audit_updated_on,
    msi.country,
    gp.grupo,
    msi.domain,
    msi.state,
    msi.current_segment,
    gmv.avg_gmv_usd_last_3m,
    gmv.avg_orders_last_3m
