SELECT
    ss.first_seller_at as date, --- consolidated_date a charlar con Ron
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
    -- NO aplican aquí las de created_at
    cast(null as bigint) as trials_last_click,
    cast(null as bigint) as trials_first_click,
    cast(null as bigint) as trials_mean_click,

    cast(null as bigint) as qls_last_click,
    cast(null as bigint) as qls_first_click,
    cast(null as bigint) as qls_mean_click,

    cast(null as bigint) as payment_created_at_last_click,
    cast(null as bigint) as payment_created_at_first_click,
    cast(null as bigint) as payment_created_at_mean_click,

    -- sellers por created_at no aplican aquí
    cast(null as bigint) as new_seller_created_at_last_click,
    cast(null as bigint) as new_seller_created_at_first_click,
    cast(null as bigint) as new_seller_created_at_mean_click,

    -- new payments y new sellers por first_payment no aplican aquí
    cast(null as bigint) as new_payment_last_click,
    cast(null as bigint) as new_payment_first_click,
    cast(null as bigint) as new_payment_mean_click,

    cast(null as bigint) as new_seller_fpd_last_click,
    cast(null as bigint) as new_seller_fpd_first_click,
    cast(null as bigint) as new_seller_fpd_mean_click,

    -- sellers por first_seller_at
    sum(case when ss.new_seller = true then trials_last_click  else 0 end) as new_seller_last_click,
    sum(case when ss.new_seller = true then trials_first_click else 0 end) as new_seller_first_click,
    sum(case when ss.new_seller = true then trials_mean_click  else 0 end) as new_seller_mean_click,

    MAX(ss.sys_audit_updated_on) as max_sys_audit_updated_on
FROM {{ref('s__general__mkt_attribution_model__event')}} att
LEFT JOIN {{ref('s__attributes__store_core__ref')}} msi on att.store_id = msi.store_id
LEFT JOIN {{ref('s__lifecycle__store_status__ref')}} ss on att.store_id = ss.store_id
WHERE ss.first_seller_at is not null
AND ss.first_seller_at >= '2018-01-01'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15