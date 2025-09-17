SELECT 
    store_id,
    CAST(date_trunc('week', completed_at) AS DATE) AS date_from,

    COALESCE(COUNT(*), 0) AS snapshot_orders_weekly,
    COALESCE(ROUND(SUM(total_in_usd), 2), 0) AS snapshot_gmv_usd_weekly,
    COALESCE(ROUND(SUM(total), 2), 0) AS snapshot_gmv_local_currency_weekly,

    -- On Platform
    COALESCE(COUNT(CASE WHEN po.platform_type = 'on' THEN po.id END), 0) AS snapshot_orders_on_platform_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.platform_type = 'on' THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_on_platform_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.platform_type = 'on' THEN po.total END), 2), 0) AS snapshot_gmv_local_currency_on_platform_weekly,

    -- Off Platform
    COALESCE(COUNT(CASE WHEN po.platform_type = 'off' AND po.storefront IS NOT NULL THEN po.id END), 0) AS snapshot_orders_off_platform_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.platform_type = 'off' AND po.storefront IS NOT NULL THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_off_platform_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.platform_type = 'off' AND po.storefront IS NOT NULL THEN po.total END), 2), 0) AS snapshot_gmv_local_currency_off_platform_weekly,

    -- Metrics by Storefront: mobile
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'mobile' THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_mobile_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'mobile' THEN po.total END), 2), 0) AS snapshot_gmv_local_mobile_weekly,
    COALESCE(COUNT(CASE WHEN po.storefront = 'mobile' THEN po.id END), 0) AS snapshot_orders_mobile_weekly,

    -- store
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'store' THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_store_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'store' THEN po.total END), 2), 0) AS snapshot_gmv_local_store_weekly,
    COALESCE(COUNT(CASE WHEN po.storefront = 'store' THEN po.id END), 0) AS snapshot_orders_store_weekly,

    -- form
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'form' THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_form_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'form' THEN po.total END), 2), 0) AS snapshot_gmv_local_form_weekly,
    COALESCE(COUNT(CASE WHEN po.storefront = 'form' THEN po.id END), 0) AS snapshot_orders_form_weekly,

    -- social
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'social' THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_social_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'social' THEN po.total END), 2), 0) AS snapshot_gmv_local_social_weekly,
    COALESCE(COUNT(CASE WHEN po.storefront = 'social' THEN po.id END), 0) AS snapshot_orders_social_weekly,

    -- pos
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'pos' THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_pos_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'pos' THEN po.total END), 2), 0) AS snapshot_gmv_local_pos_weekly,
    COALESCE(COUNT(CASE WHEN po.storefront = 'pos' THEN po.id END), 0) AS snapshot_orders_pos_weekly,

    -- API - App Specific (12217)
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'api' AND po.platform_type = 'on' THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_api_app12217_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'api' AND po.platform_type = 'on' THEN po.total END), 2), 0) AS snapshot_gmv_local_api_app12217_weekly,
    COALESCE(COUNT(CASE WHEN po.storefront = 'api' AND po.platform_type = 'on' THEN po.id END), 0) AS snapshot_orders_api_app12217_weekly,

    -- API - Other Apps
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'api' AND po.platform_type = 'off' THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_api_other_apps_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.storefront = 'api' AND po.platform_type = 'off' THEN po.total END), 2), 0) AS snapshot_gmv_local_api_other_apps_weekly,
    COALESCE(COUNT(CASE WHEN po.storefront = 'api' AND po.platform_type = 'off' THEN po.id END), 0) AS snapshot_orders_api_other_apps_weekly,

    -- Others
    COALESCE(ROUND(SUM(CASE WHEN po.storefront NOT IN ('mobile', 'store', 'form', 'social', 'pos', 'api') THEN po.total_in_usd END), 2), 0) AS snapshot_gmv_usd_others_weekly,
    COALESCE(ROUND(SUM(CASE WHEN po.storefront NOT IN ('mobile', 'store', 'form', 'social', 'pos', 'api') THEN po.total END), 2), 0) AS snapshot_gmv_local_others_weekly,
    COALESCE(COUNT(CASE WHEN po.storefront NOT IN ('mobile', 'store', 'form', 'social', 'pos', 'api') THEN po.id END), 0) AS snapshot_orders_others_weekly

FROM 
    {{ ref('company_metrics_paid_orders') }} po

WHERE
    date_trunc('week', completed_at) < date_trunc('week', current_date)

GROUP BY 1, 2