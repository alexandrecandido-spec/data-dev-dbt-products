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
	{{ ref('_int_finance_store_gmv_and_segments__active_merchants') }}
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
	{{ ref('_int_finance_store_gmv_and_segments__active_merchants') }}
    )

SELECT
	ad.datemonth,
	cs.store_id,
	msi.country,
	fo.country_currency,
	DATE(msi.created_at),
    ROUND(
          GREATEST(1,
		90 / DATEDIFF(ad.datemonth,
		msi.created_at))
        ) AS proportional,
	CASE
		WHEN DATEDIFF(ad.datemonth,
		msi.created_at) < 90 THEN 1
		ELSE 0
	END AS proportional_segment,
	CASE
		WHEN am.store_id IS NOT NULL THEN 1
		ELSE 0
	END AS is_paying_merchant,
	-- General (todas las órdenes)
      COALESCE(
        COUNT(
          CASE
            WHEN DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
            AND ad.datemonth THEN fo.id
          END
        ),
	0
      ) AS orders_general_month,
	COALESCE(
        SUM(
          CASE
            WHEN DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
            AND ad.datemonth THEN fo.total_in_usd_billing
          END
        ),
	0
      ) AS gmv_general_month,
	COALESCE(
        ROUND(
          SUM(
            CASE
              WHEN DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
              AND ad.datemonth THEN fo.total_in_local_currency
            END
          ),
	2
        ),
	0
      ) AS gmv_local_general_month,
	COALESCE(
        COUNT(
          CASE
            WHEN DATE(fo.completed_at) BETWEEN DATEADD(DAY, -90, ad.datemonth)
            AND ad.datemonth THEN fo.id
          END
        ),
	0
      ) AS orders_general_90d,
	-- On Platform (storefront en 'mobile', 'store', 'form', 'social')
      COALESCE(
        COUNT(
          CASE
            WHEN fo.storefront IN ('mobile', 'store', 'form', 'social')
            AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
            AND ad.datemonth THEN fo.id
          END
        ),
	0
      ) AS orders_on_platform_month,
	COALESCE(
        SUM(
          CASE
            WHEN fo.storefront IN ('mobile', 'store', 'form', 'social')
            AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
            AND ad.datemonth THEN fo.total_in_usd_billing
          END
        ),
	0
      ) AS gmv_on_platform_month,
	COALESCE(
        ROUND(
          SUM(
            CASE
              WHEN fo.storefront IN ('mobile', 'store', 'form', 'social')
              AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
              AND ad.datemonth THEN fo.total_in_local_currency
            END
          ),
	2
        ),
	0
      ) AS gmv_local_on_platform_month,
	COALESCE(
        COUNT(
          CASE
            WHEN fo.storefront IN ('mobile', 'store', 'form', 'social')
            AND DATE(fo.completed_at) BETWEEN DATEADD(DAY, -90, ad.datemonth)
            AND ad.datemonth THEN fo.id
          END
        ),
	0
      ) AS orders_on_platform_90d,
	-- Off Platform (lo contrario a On Platform)
      COALESCE(
        COUNT(
          CASE
            WHEN fo.storefront NOT IN ('mobile', 'store', 'form', 'social')
            AND fo.storefront IS NOT NULL
            AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
            AND ad.datemonth THEN fo.id
          END
        ),
	0
      ) AS orders_off_platform_month,
	COALESCE(
        SUM(
          CASE
            WHEN fo.storefront NOT IN ('mobile', 'store', 'form', 'social')
            AND fo.storefront IS NOT NULL
            AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
            AND ad.datemonth THEN fo.total_in_usd_billing
          END
        ),
	0
      ) AS gmv_off_platform_month,
	COALESCE(
        ROUND(
          SUM(
            CASE
              WHEN fo.storefront NOT IN ('mobile', 'store', 'form', 'social')
              AND fo.storefront IS NOT NULL
              AND DATE(fo.completed_at) BETWEEN DATE_TRUNC('month', ad.datemonth)
              AND ad.datemonth THEN fo.total_in_local_currency
            END
          ),
	2
        ),
	0
      ) AS gmv_local_off_platform_month,
	COALESCE(
        COUNT(
          CASE
            WHEN fo.storefront NOT IN ('mobile', 'store', 'form', 'social')
            AND fo.storefront IS NOT NULL
            AND DATE(fo.completed_at) BETWEEN DATEADD(DAY, -90, ad.datemonth)
            AND ad.datemonth THEN fo.id
          END
        ),
	0
      ) AS orders_off_platform_90d
FROM
	all_dates ad
CROSS JOIN combined_stores cs
LEFT JOIN {{ ref('finance_paid_orders_store_summary') }} fo ON
	cs.store_id = fo.store_id
LEFT JOIN {{ ref('_int_finance_store_gmv_and_segments__active_merchants') }} am ON
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
	DATE(msi.created_at),
	msi.country
