-- Owner: YAN GERMANO
-- Model: affiliates_metrics_gold

WITH base_general AS (
    SELECT
        partner_id,
        country_code,
        is_store_blocked,
        new_seller,
        CAST(created_at AS DATE) AS date,

        COUNT(DISTINCT store_id) AS trials,
        0 AS new_payments,
        COUNT(DISTINCT CASE WHEN new_payment = 1 THEN store_id END) AS payments,
        0 AS new_sellers,
        0 AS current_churn_stores,
        0 AS first_churn_30d,
        0 AS first_churn_60d,
        0 AS first_churn_90d,
        0 AS first_churn_post_90d,
        0 AS total_gmv,
        0 AS total_orders,
        COUNT(DISTINCT CASE WHEN is_quality_lead = 1 THEN store_id END) AS qls,
        COUNT(DISTINCT CASE WHEN churned_at IS NOT NULL THEN store_id END) AS current_churn_stores_created_at,
        0 AS new_sellers_first_payment
    FROM {{ ref('_int__affiliates_general_tabla') }}
    WHERE created_at >= '2023-01-01'
    GROUP BY 1, 2, 3, 4, 5
),

base_first_payment AS (
    SELECT
        partner_id,
        country_code,
        is_store_blocked,
        new_seller,
        CAST(first_payment AS DATE) AS date,

        0 AS trials,
        COUNT(DISTINCT CASE WHEN new_payment = 1 THEN store_id END) AS new_payments,
        0 AS payments,
        0 AS new_sellers,
        0 AS current_churn_stores,
        0 AS first_churn_30d,
        0 AS first_churn_60d,
        0 AS first_churn_90d,
        0 AS first_churn_post_90d,
        0 AS total_gmv,
        0 AS total_orders,
        0 AS qls,
        0 AS current_churn_stores_created_at,
        COUNT(DISTINCT CASE WHEN new_seller = TRUE THEN store_id END) AS new_sellers_first_payment
    FROM {{ ref('_int__affiliates_general_tabla') }}
    WHERE first_payment >= '2020-01-01'
    GROUP BY 1, 2, 3, 4, 5
),

base_new_sellers AS (
    SELECT
        partner_id,
        country_code,
        is_store_blocked,
        new_seller,
        CAST(first_seller_at AS DATE) AS date,

        0 AS trials,
        0 AS new_payments,
        0 AS payments,
        COUNT(DISTINCT store_id) AS new_sellers,
        0 AS current_churn_stores,
        0 AS first_churn_30d,
        0 AS first_churn_60d,
        0 AS first_churn_90d,
        0 AS first_churn_post_90d,
        0 AS total_gmv,
        0 AS total_orders,
        0 AS qls,
        0 AS current_churn_stores_created_at,
        0 AS new_sellers_first_payment
    FROM {{ ref('_int__affiliates_general_tabla') }}
    WHERE new_seller = TRUE
      AND first_seller_at >= '2023-01-01'
    GROUP BY 1, 2, 3, 4, 5
),

base_current_churn AS (
    SELECT
        partner_id,
        country_code,
        is_store_blocked,
        new_seller,
        CAST(churned_at AS DATE) AS date,

        0 AS trials,
        0 AS new_payments,
        0 AS payments,
        0 AS new_sellers,
        COUNT(DISTINCT store_id) AS current_churn_stores,
        0 AS first_churn_30d,
        0 AS first_churn_60d,
        0 AS first_churn_90d,
        0 AS first_churn_post_90d,
        0 AS total_gmv,
        0 AS total_orders,
        0 AS qls,
        0 AS current_churn_stores_created_at,
        0 AS new_sellers_first_payment
    FROM {{ ref('_int__affiliates_general_tabla') }}
    WHERE churned_at IS NOT NULL
      AND churned_at >= '2023-01-01'
    GROUP BY 1, 2, 3, 4, 5
),

base_gmv AS (
    SELECT
        t.partner_id,
        t.country_code,
        t.is_store_blocked,
        t.new_seller,
        CAST(g.date AS DATE) AS date,

        0 AS trials,
        0 AS new_payments,
        0 AS payments,
        0 AS new_sellers,
        0 AS current_churn_stores,
        0 AS first_churn_30d,
        0 AS first_churn_60d,
        0 AS first_churn_90d,
        0 AS first_churn_post_90d,
        SUM(g.gmv) AS total_gmv,
        SUM(g.orders) AS total_orders,
        0 AS qls,
        0 AS current_churn_stores_created_at,
        0 AS new_sellers_first_payment
    FROM {{ ref('_int__affiliates_general_tabla') }} AS t
    INNER JOIN {{ ref('g__operations__orders_gmv_store__agg_daily') }} AS g
        ON t.store_id = g.store_id
    WHERE g.date >= '2023-01-01'
    GROUP BY 1, 2, 3, 4, 5
),

base_first_churn AS (
    SELECT
        partner_id,
        country_code,
        is_store_blocked,
        new_seller,
        CAST(churn_date AS DATE) AS date,

        0 AS trials,
        0 AS new_payments,
        0 AS payments,
        0 AS new_sellers,
        0 AS current_churn_stores,
        SUM(churn_30d) AS first_churn_30d,
        SUM(churn_60d) AS first_churn_60d,
        SUM(churn_90d) AS first_churn_90d,
        SUM(churn_post_90d) AS first_churn_post_90d,
        0 AS total_gmv,
        0 AS total_orders,
        0 AS qls,
        0 AS current_churn_stores_created_at,
        0 AS new_sellers_first_payment
    FROM {{ ref('_int__affiliates_churn_flag') }}
    WHERE churn_date >= '2023-01-01'
    GROUP BY 1, 2, 3, 4, 5
),

all_metrics AS (
    SELECT * FROM base_general
    UNION ALL
    SELECT * FROM base_first_payment
    UNION ALL
    SELECT * FROM base_new_sellers
    UNION ALL
    SELECT * FROM base_current_churn
    UNION ALL
    SELECT * FROM base_gmv
    UNION ALL
    SELECT * FROM base_first_churn
)

-- ==========================================
-- Agregação final consolidada
-- ==========================================
SELECT
    partner_id,
    country_code,
    is_store_blocked,
    new_seller,
    date,

    SUM(trials) AS trials,
    SUM(new_payments) AS new_payments,
    SUM(payments) AS payments,
    SUM(new_sellers) AS new_sellers,
    SUM(current_churn_stores) AS current_churn_stores,
    SUM(first_churn_30d) AS first_churn_30d,
    SUM(first_churn_60d) AS first_churn_60d,
    SUM(first_churn_90d) AS first_churn_90d,
    SUM(first_churn_post_90d) AS first_churn_post_90d,
    ROUND(SUM(total_gmv), 2) AS total_gmv,
    ROUND(SUM(total_orders), 2) AS total_orders,
    SUM(qls) AS qls,
    SUM(current_churn_stores_created_at) AS current_churn_stores_created_at,
    SUM(new_sellers_first_payment) AS new_sellers_first_payment

FROM all_metrics
GROUP BY 1, 2, 3, 4, 5
