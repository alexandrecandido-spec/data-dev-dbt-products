-- Owner: YAN GERMANO
-- Define a lista de todas as colunas de métricas para a macro
{% set metric_cols = [
    'trials', 'new_payments', 'payments', 'new_sellers', 'current_churn_stores', 
    'first_churn_30d', 'first_churn_60d', 'first_churn_90d', 'first_churn_post_90d', 
    'total_gmv', 'total_orders', 'qls', 'current_churn_stores_created_at', 'new_sellers_first_payment'
] %}

WITH base AS (

    -- Trials
    {{ generate_metric_union('_int__affiliates_metrics_created_at', 'trials', metric_cols) }}

    UNION ALL

    -- Payments
    {{ generate_metric_union('_int__affiliates_metrics_created_at', 'payments', metric_cols) }}

    UNION ALL

    -- Current Churn Stores Created At
    {{ generate_metric_union('_int__affiliates_metrics_created_at', 'current_churn_stores_created_at', metric_cols) }}

    UNION ALL

    -- New Payments
    {{ generate_metric_union('_int__affiliates_first_payment', 'new_payments', metric_cols) }}

    UNION ALL

    -- New Sellers First Payment
    {{ generate_metric_union('_int__affiliates_first_payment', 'new_sellers_first_payment', metric_cols) }}

    UNION ALL

    -- New Sellers
    {{ generate_metric_union('_int__affiliates_new_sellers', 'new_sellers', metric_cols) }}

    UNION ALL

    -- Current Churned Stores
    {{ generate_metric_union('_int__affiliates_current_churned', 'current_churn_stores', metric_cols) }}

    UNION ALL

    -- Quality Leads
    {{ generate_metric_union('_int__affiliates_qls', 'qls', metric_cols) }}

    UNION ALL

    -- First Churn
    SELECT
        partner_id,
        country_code,
        is_store_blocked,
        new_seller,
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
        0 AS qls,
        0 AS current_churn_stores_created_at,
        0 AS new_sellers_first_payment
    FROM {{ ref('_int__affiliates_first_churns') }}

    UNION ALL

    -- GMV and Orders
    SELECT
        partner_id,
        country_code,
        is_store_blocked,
        new_seller,
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
        0 AS qls,
        0 AS current_churn_stores_created_at,
        0 AS new_sellers_first_payment
    FROM {{ ref('_int__affiliates_gmv') }}
)

-- =====================================================
-- Final Aggregation (by partner, country and date)
-- =====================================================

SELECT
    partner_id,
    country_code,
    is_store_blocked,
    new_seller,
    date,

    -- Main Metrics
    SUM(trials) AS trials,
    SUM(new_payments) AS new_payments,
    SUM(payments) AS payments,
    SUM(new_sellers) AS new_sellers,
    SUM(current_churn_stores) AS current_churn_stores,
    SUM(qls) AS qls,
    SUM(current_churn_stores_created_at) AS current_churn_stores_created_at,
    SUM(new_sellers_first_payment) AS new_sellers_first_payment,

    -- First Churns
    SUM(first_churn_30d) AS first_churn_30d,
    SUM(first_churn_60d) AS first_churn_60d,
    SUM(first_churn_90d) AS first_churn_90d,
    SUM(first_churn_post_90d) AS first_churn_post_90d,

    -- GMV and Orders
    ROUND(SUM(total_gmv), 2) AS total_gmv,
    ROUND(SUM(total_orders), 2) AS total_orders
FROM base
GROUP BY 1, 2, 3, 4, 5
