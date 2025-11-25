SELECT
    msi.created_at as date, --- consolidated_date a charlar con Ron
    att.store_id,
    att.country_code,
    att.source,
    att.medium,
    att.campaign,
    att.content,
    att.referrer_domain,
    att.referrer_path,
    att.landing_page_domain,
    att.landing_page_path,
    att.register_url,
    msi.partner_id,
    att.mkt_source,
    att.mkt_subteam,
    -- created_at metrics
    sum(trials_last_click)  as trials_last_click,
    sum(trials_first_click) as trials_first_click,
    sum(trials_mean_click)  as trials_mean_click,

    sum(case when acq.is_quality_lead = 1 then trials_last_click  else 0 end) as qls_last_click,
    sum(case when acq.is_quality_lead = 1 then trials_first_click else 0 end) as qls_first_click,
    sum(case when acq.is_quality_lead = 1 then trials_mean_click  else 0 end) as qls_mean_click,

    sum(case when ss.new_payment = true then trials_last_click  else 0 end) as payment_created_at_last_click,
    sum(case when ss.new_payment = true then trials_first_click else 0 end) as payment_created_at_first_click,
    sum(case when ss.new_payment = true then trials_mean_click  else 0 end) as payment_created_at_mean_click,

    -- sellers por created_at
    sum(case when ss.new_seller = true then trials_last_click  else 0 end) as new_seller_created_at_last_click,
    sum(case when ss.new_seller = true then trials_first_click else 0 end) as new_seller_created_at_first_click,
    sum(case when ss.new_seller = true then trials_mean_click  else 0 end) as new_seller_created_at_mean_click,

    -- columnas que NO aplican en esta CTE (first_payment / first_seller_at)
    cast(null as bigint) as new_payment_last_click,
    cast(null as bigint) as new_payment_first_click,
    cast(null as bigint) as new_payment_mean_click,

    cast(null as bigint) as new_seller_fpd_last_click,
    cast(null as bigint) as new_seller_fpd_first_click,
    cast(null as bigint) as new_seller_fpd_mean_click,

    cast(null as bigint) as new_seller_last_click,
    cast(null as bigint) as new_seller_first_click,
    cast(null as bigint) as new_seller_mean_click,

    MAX(att.sys_audit_updated_on) as max_sys_audit_updated_on
    
FROM {{ref('s__general__mkt_attribution_model__event')}} att
LEFT JOIN {{ref('s__attributes__store_core__ref')}} msi on att.store_id = msi.store_id
LEFT JOIN {{ref('s__attributes__acquisition_profile__ref')}} acq on att.store_id = acq.store_id
LEFT JOIN {{ref('s__lifecycle__store_status__ref')}} ss on att.store_id = ss.store_id
WHERE msi.created_at >= '2018-01-01'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,11, 12, 13, 14, 15