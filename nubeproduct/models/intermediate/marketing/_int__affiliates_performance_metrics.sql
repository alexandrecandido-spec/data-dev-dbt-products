-- Define a lista de todas as colunas de métricas para a macro
{% set metric_cols = [
    'trials', 'new_payments', 'payments', 'new_sellers', 'current_churn_stores', 
    'first_churn_30d', 'first_churn_60d', 'first_churn_90d', 'first_churn_post_90d', 
    'total_gmv', 'total_orders', 'gmv_30d', 'orders_30d', 'gmv_90d', 'orders_90d'
] %}

WITH base AS (

    -- 📍 Trials and Payments
    {{ generate_metric_union('_int__affiliates_metrics_created_at', 'trials', metric_cols) }}

    UNION ALL

    -- 📍 New Payments
    {{ generate_metric_union('_int__affiliates_metrics_created_at', 'payments', metric_cols) }}

    UNION ALL

    -- 💰 New Payments
    {{ generate_metric_union('_int__affiliates_new_payments', 'new_payments', metric_cols) }}

    UNION ALL

    -- 🛍️ New Sellers
    {{ generate_metric_union('_int__affiliates_new_sellers', 'new_sellers', metric_cols) }}

    UNION ALL

    -- ❌ Current Churned
    {{ generate_metric_union('_int__affiliates_current_churned', 'current_churn_stores', metric_cols) }}

    UNION ALL

    -- 📉 First Churn
    SELECT
        partner_id,
        country_code,
        date,
        0 AS trials,
        0 AS new_payments,
        0 AS payments,
        0 AS new_sellers,
        0 AS current_churn_stores,
        first_churn_30d,
        first_churn_60d,
        first_churn_90d,
        first_churn_post_90d,
        0 AS total_gmv,
        0 AS total_orders,
        0 AS gmv_30d,
        0 AS orders_30d,
        0 AS gmv_90d,
        0 AS orders_90d
    FROM {{ ref('_int__affiliates_first_churns') }}

    UNION ALL

    -- 💵 GMV and Orders
    SELECT
        partner_id,
        country_code,
        date,
        0 AS trials,
        0 AS new_payments,
        0 AS payments,
        0 AS new_sellers,
        0 AS current_churn_stores,
        0 AS first_churn_30d,
        0 AS first_churn_60d,
        0 AS first_churn_90d,
        0 AS first_churn_post_90d,
        total_gmv,
        total_orders,
        gmv_30d,
        orders_30d,
        gmv_90d,
        orders_90d
    FROM {{ ref('_int__affiliates_gmv') }}
)

-- =====================================================
-- 🎯 Final Aggregation (by partner, country and date)
-- =====================================================

SELECT
    partner_id,
    country_code,
    date,

    -- 🧮 Main Metrics
    SUM(trials) AS trials,
    SUM(new_payments) AS new_payments,
    SUM(payments) AS payments,
    SUM(new_sellers) AS new_sellers,
    SUM(current_churn_stores) AS current_churn_stores,

    -- 📉 First Churns
    SUM(first_churn_30d) AS first_churn_30d,
    SUM(first_churn_60d) AS first_churn_60d,
    SUM(first_churn_90d) AS first_churn_90d,
    SUM(first_churn_post_90d) AS first_churn_post_90d,

    -- 💵 GMV and Orders
    ROUND(SUM(total_gmv), 2) AS total_gmv,
    ROUND(SUM(total_orders), 2) AS total_orders,
    ROUND(SUM(gmv_30d), 2) AS gmv_30d,
    ROUND(SUM(orders_30d), 2) AS orders_30d,
    ROUND(SUM(gmv_90d), 2) AS gmv_90d,
    ROUND(SUM(orders_90d), 2) AS orders_90d
FROM base
GROUP BY 1, 2, 3
