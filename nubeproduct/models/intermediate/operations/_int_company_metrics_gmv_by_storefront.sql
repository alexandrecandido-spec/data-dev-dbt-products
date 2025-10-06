WITH months AS (
SELECT
	DATE(
          DATEADD(
            DAY,
	-1,
	DATEADD(MONTH,
	1,
	DATE_TRUNC('month',
	generated_date))
          )
        ) AS datemonth
FROM
	(
	SELECT
		DISTINCT DATE_TRUNC('month',
		DATE(completed_at)) AS generated_date
	FROM
		{{ ref('orders__mwp_orders') }}
	WHERE
		DATE(completed_at) >= '2021-09-01'
		AND DATE(completed_at) <= DATE(current_date)
        AND total_in_usd <= 10000 and total_in_usd >= 0
        )
    ),
stores AS (
SELECT
	DISTINCT store_id
FROM
	{{ ref('orders__mwp_orders') }}
WHERE
	DATE(completed_at) >= DATEADD(DAY,
  CASE WHEN {{ is_incremental() }} THEN -120 ELSE
	-1460
  END,
	current_date)
    ),

combined_stores AS (
SELECT
	DISTINCT store_id
FROM
	stores
UNION
SELECT
	DISTINCT store_id
FROM
	{{ ref('_int_company_metrics_gmv_and_segments__active_merchants') }}
    ),
    
    all_dates AS (
SELECT
	DISTINCT datemonth
FROM
	months
UNION
SELECT
	DISTINCT datemonth
FROM
	{{ ref('_int_company_metrics_gmv_and_segments__active_merchants') }}
    )

SELECT
    ad.datemonth,
    cs.store_id,
    msi.country,
    fo.country_currency,
    DATE(msi.created_at) AS store_creation_date,
    CASE
        WHEN am.store_id IS NOT NULL THEN TRUE
        ELSE FALSE
    END AS is_paying_merchant,
    -- Orders & GMV totals by month
    COALESCE(COUNT(CASE
            WHEN DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
            THEN fo.id END), 0)
        AS orders_total_month,
    COALESCE(SUM(CASE
            WHEN DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
            THEN fo.total_in_usd END), 0)
        AS gmv_usd_total_month,
    COALESCE(SUM(CASE
            WHEN DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
            THEN fo.total END), 0)
        AS gmv_local_total_month,

    -- Metrics by Storefront: mobile
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'mobile' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total_in_usd END), 0)
    AS gmv_usd_mobile_month,
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'mobile' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total END), 0)
    AS gmv_local_mobile_month,
    COALESCE(COUNT(CASE
        WHEN fo.storefront = 'mobile' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.id END), 0)
    AS orders_mobile_month,

    -- Metrics by Storefront: store
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'store' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total_in_usd END), 0)
    AS gmv_usd_store_month,
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'store' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total END), 0)
    AS gmv_local_store_month,
    COALESCE(COUNT(CASE
        WHEN fo.storefront = 'store' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.id END), 0)
    AS orders_store_month,

    -- Metrics by Storefront: form
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'form' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total_in_usd END), 0)
    AS gmv_usd_form_month,
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'form' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total END), 0)
    AS gmv_local_form_month,
    COALESCE(COUNT(CASE
        WHEN fo.storefront = 'form' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.id END), 0)
    AS orders_form_month,

    -- Metrics by Storefront: social
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'social' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total_in_usd END), 0)
    AS gmv_usd_social_month,
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'social' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total END), 0)
    AS gmv_local_social_month,
    COALESCE(COUNT(CASE
        WHEN fo.storefront = 'social' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.id END), 0)
    AS orders_social_month,

    -- Metrics by Storefront: pos
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'pos' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total_in_usd END), 0)
    AS gmv_usd_pos_month,
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'pos' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total END), 0)
    AS gmv_local_pos_month,
    COALESCE(COUNT(CASE
        WHEN fo.storefront = 'pos' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.id END), 0)
    AS orders_pos_month,

    -- Metrics by Storefront: API - App Specific (12217)
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'api' AND platform_type = 'on' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total_in_usd END), 0)
    AS gmv_usd_api_app12217_month,
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'api' AND platform_type = 'on' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total END), 0)
    AS gmv_local_api_app12217_month,
    COALESCE(COUNT(CASE
        WHEN fo.storefront = 'api' AND platform_type = 'on' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.id END), 0)
    AS orders_api_app12217_month,

    -- Metrics by Storefront: API - Other Apps
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'api' AND platform_type = 'off' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total_in_usd END), 0)
    AS gmv_usd_api_other_apps_month,
    COALESCE(SUM(CASE
        WHEN fo.storefront = 'api' AND platform_type = 'off' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total END), 0)
    AS gmv_local_api_other_apps_month,
    COALESCE(COUNT(CASE
        WHEN fo.storefront = 'api' AND platform_type = 'off' AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.id END), 0)
    AS orders_api_other_apps_month,

    -- Metrics by Storefront: Others (not specified above)
    COALESCE(SUM(CASE
        WHEN fo.storefront NOT IN ('mobile', 'store', 'form', 'social', 'pos', 'api') AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total_in_usd END), 0)
    AS gmv_usd_others_month,
    COALESCE(SUM(CASE
        WHEN fo.storefront NOT IN ('mobile', 'store', 'form', 'social', 'pos', 'api') AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.total END), 0)
    AS gmv_local_others_month,
    COALESCE(COUNT(CASE
        WHEN fo.storefront NOT IN ('mobile', 'store', 'form', 'social', 'pos', 'api') AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth) AND ad.datemonth
        THEN fo.id END), 0)
    AS orders_others_month

FROM
    all_dates ad
CROSS JOIN combined_stores cs
LEFT JOIN {{ ref('company_metrics_paid_orders') }} fo ON
    cs.store_id = fo.store_id
LEFT JOIN {{ ref('_int_company_metrics_gmv_and_segments__active_merchants') }} am ON
    cs.store_id = am.store_id
    AND ad.datemonth = am.datemonth
INNER JOIN {{ ref('moltres__mwp_store_info') }} msi ON
    cs.store_id = msi.store_id
WHERE
    ad.datemonth <= DATEADD(
        DAY,
    1 - EXTRACT(
          DAY
FROM
    CURRENT_DATE
        ),
    CURRENT_DATE
      )
GROUP BY
    ad.datemonth,
    cs.store_id,
    is_paying_merchant,
    fo.country_currency,
    store_creation_date,
    msi.country