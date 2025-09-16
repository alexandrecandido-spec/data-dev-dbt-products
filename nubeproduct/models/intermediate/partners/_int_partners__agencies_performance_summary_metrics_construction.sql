WITH partners_metrics AS -- Create a table with the metrics for each partner considering the snapshot date
(
    SELECT 
        partner_id,
        partner_code,
        partner_created_at,
        partner_country_code,
        snapshot_date,
        SUM(CASE WHEN created_at <= snapshot_date THEN 1 ELSE 0 END) AS all_time_stores,
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment <= snapshot_date THEN 1 ELSE 0 END) AS all_time_new_payments,
        SUM(CASE WHEN first_seller_at IS NOT NULL AND first_seller_at <= snapshot_date THEN 1 ELSE 0 END) AS all_time_new_sellers,
        MIN(CASE WHEN created_at <= snapshot_date THEN created_at ELSE NULL END) AS first_trial_at,
        MIN(CASE WHEN first_payment_flg = TRUE AND first_payment <= snapshot_date THEN first_payment ELSE NULL END) AS first_payment_at,
        MIN(CASE WHEN first_seller_at IS NOT NULL AND first_seller_at <= snapshot_date THEN first_seller_at ELSE NULL END) AS first_seller_at,
        SUM(CASE WHEN 
            (first_payment IS NULL OR first_payment > snapshot_date)
            AND (churned_at IS NULL OR churned_at > snapshot_date)
            AND plan_group = 'freemium' 
            THEN 1 ELSE 0 END) AS freemium_stores,
        SUM(CASE WHEN 
            (first_payment IS NULL OR first_payment > snapshot_date)
            AND (churned_at IS NULL OR churned_at > snapshot_date)
            AND plan_group != 'freemium' 
        THEN 1 ELSE 0 END) AS active_trials,
        SUM(CASE WHEN 
            first_payment IS NOT NULL 
            AND first_payment <= snapshot_date 
            AND (churned_at IS NULL OR churned_at > snapshot_date) 
        THEN 1 ELSE 0 END) AS active_paying_stores,
        SUM(CASE WHEN             
            (first_payment IS NULL OR first_payment > snapshot_date)
                AND (churned_at IS NULL OR churned_at > snapshot_date)
                AND plan_group = 'freemium'  
                AND gmv_usd_last_90d > 0 
        THEN 1 ELSE 0 END) AS freemium_stores_with_gmv_last_90_days,
        SUM(CASE WHEN churned_at IS NOT NULL AND churned_at <= snapshot_date THEN 1 ELSE 0 END) AS churned_stores,
        -- Current month metrics
        SUM(CASE WHEN 
                DATE_TRUNC('MONTH', created_at) = DATE_TRUNC('MONTH', snapshot_date)
                AND created_at <=  snapshot_date
            THEN 1 ELSE 0 END) AS trials_current_month,
        SUM(CASE WHEN 
                first_payment_flg = TRUE 
                AND DATE_TRUNC('MONTH', first_payment) = DATE_TRUNC('MONTH', snapshot_date)
                AND first_payment <= snapshot_date THEN 1 ELSE 0 END) AS new_payments_current_month,
        SUM(CASE WHEN 
                DATE_TRUNC('MONTH', first_seller_at) = DATE_TRUNC('MONTH', snapshot_date)
                AND first_seller_at <= snapshot_date
            THEN 1 ELSE 0 END) AS new_sellers_current_month,
        -- AQUÍ SE SUMA EL GMV DE stores_gmv - con COALESCE para evitar NULLs
        SUM(COALESCE(gmv_usd_current_month, 0)) AS gmv_usd_current_month,
        SUM(COALESCE(gmv_local_currency_current_month, 0)) AS gmv_local_currency_current_month,
        -- Previous month metrics
        SUM(CASE WHEN DATE_TRUNC('MONTH', created_at) = DATE_TRUNC('MONTH', ADD_MONTHS(snapshot_date, -1)) THEN 1 ELSE 0 END) AS trials_previous_month,
        SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('MONTH', first_payment) = DATE_TRUNC('MONTH', ADD_MONTHS(snapshot_date, -1)) THEN 1 ELSE 0 END) AS new_payments_previous_month,
        SUM(CASE WHEN DATE_TRUNC('MONTH', first_seller_at) = DATE_TRUNC('MONTH', ADD_MONTHS(snapshot_date, -1)) THEN 1 ELSE 0 END) AS new_sellers_previous_month,
        SUM(COALESCE(gmv_usd_previous_month, 0)) AS gmv_usd_previous_month,
        SUM(COALESCE(gmv_local_currency_previous_month, 0)) AS gmv_local_currency_previous_month,
        -- Last quarter metrics
        SUM(CASE WHEN DATE_TRUNC('QUARTER', created_at) = DATE_TRUNC('QUARTER', ADD_MONTHS(snapshot_date, -3)) THEN 1 ELSE 0 END) AS trials_last_quarter,
        SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('QUARTER', first_payment) = DATE_TRUNC('QUARTER', ADD_MONTHS(snapshot_date, -3)) THEN 1 ELSE 0 END) AS new_payments_last_quarter,
        SUM(CASE WHEN DATE_TRUNC('QUARTER', first_seller_at) = DATE_TRUNC('QUARTER', ADD_MONTHS(snapshot_date, -3)) THEN 1 ELSE 0 END) AS new_sellers_last_quarter,
        SUM(COALESCE(gmv_usd_last_quarter, 0)) AS gmv_usd_last_quarter,
        SUM(COALESCE(gmv_local_currency_last_quarter, 0)) AS gmv_local_currency_last_quarter,
        -- Last year metrics
        SUM(CASE WHEN DATE_TRUNC('YEAR', created_at) = DATE_TRUNC('YEAR', ADD_MONTHS(snapshot_date, -12)) THEN 1 ELSE 0 END) AS trials_last_year,
        SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('YEAR', first_payment) = DATE_TRUNC('YEAR', ADD_MONTHS(snapshot_date, -12)) THEN 1 ELSE 0 END) AS new_payments_last_year,
        SUM(CASE WHEN DATE_TRUNC('YEAR', first_seller_at) = DATE_TRUNC('YEAR', ADD_MONTHS(snapshot_date, -12)) THEN 1 ELSE 0 END) AS new_sellers_last_year,
        SUM(COALESCE(gmv_usd_last_year, 0)) AS gmv_usd_last_year,
        SUM(COALESCE(gmv_local_currency_last_year, 0)) AS gmv_local_currency_last_year,
        -- Rolling periods
        SUM(CASE WHEN created_at BETWEEN DATE_SUB(snapshot_date, 30) AND snapshot_date THEN 1 ELSE 0 END) AS trials_last_30d, 
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment BETWEEN DATE_SUB(snapshot_date, 30) AND snapshot_date THEN 1 ELSE 0 END) AS new_payments_last_30d,
        SUM(CASE WHEN first_seller_at BETWEEN DATE_SUB(snapshot_date, 30) AND snapshot_date THEN 1 ELSE 0 END) AS new_sellers_last_30d,
        SUM(COALESCE(gmv_usd_last_30d, 0)) AS gmv_usd_last_30d,
        SUM(COALESCE(gmv_local_currency_last_30d, 0)) AS gmv_local_currency_last_30d,
        -- Last 90 days metrics
        SUM(CASE WHEN created_at BETWEEN DATE_SUB(snapshot_date, 90) AND snapshot_date THEN 1 ELSE 0 END) AS trials_last_90d,
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment BETWEEN DATE_SUB(snapshot_date, 90) AND snapshot_date THEN 1 ELSE 0 END) AS new_payments_last_90d,
        SUM(CASE WHEN first_seller_at BETWEEN DATE_SUB(snapshot_date, 90) AND snapshot_date THEN 1 ELSE 0 END) AS new_sellers_last_90d,
        SUM(COALESCE(gmv_usd_last_90d, 0)) AS gmv_usd_last_90d,
        SUM(COALESCE(gmv_local_currency_last_90d, 0)) AS gmv_local_currency_last_90d,
        -- Last 180 days metrics
        SUM(CASE WHEN created_at BETWEEN DATE_SUB(snapshot_date, 180) AND snapshot_date THEN 1 ELSE 0 END) AS trials_last_180d,
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment BETWEEN DATE_SUB(snapshot_date, 180) AND snapshot_date THEN 1 ELSE 0 END) AS new_payments_last_180d,
        SUM(CASE WHEN first_seller_at BETWEEN DATE_SUB(snapshot_date, 180) AND snapshot_date THEN 1 ELSE 0 END) AS new_sellers_last_180d,
        SUM(COALESCE(gmv_usd_last_180d, 0)) AS gmv_usd_last_180d,
        SUM(COALESCE(gmv_local_currency_last_180d, 0)) AS gmv_local_currency_last_180d,
        -- Last 365 days metrics
        SUM(CASE WHEN created_at BETWEEN DATE_SUB(snapshot_date, 365) AND snapshot_date THEN 1 ELSE 0 END) AS trials_last_365d,
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment BETWEEN DATE_SUB(snapshot_date, 365) AND snapshot_date THEN 1 ELSE 0 END) AS new_payments_last_365d,
        SUM(CASE WHEN first_seller_at BETWEEN DATE_SUB(snapshot_date, 365) AND snapshot_date THEN 1 ELSE 0 END) AS new_sellers_last_365d,
        SUM(COALESCE(gmv_usd_last_365d, 0)) AS gmv_usd_last_365d,
        SUM(COALESCE(gmv_local_currency_last_365d, 0)) AS gmv_local_currency_last_365d
    FROM {{ ref('_int_partners__agencies_performance_summary_stores_data_and_gmv') }}
    GROUP BY     
        partner_id,
        partner_code,
        partner_created_at,
        partner_country_code,
        snapshot_date
)
SELECT 
    snapshot_date,
    partner_id,
    partner_code,
    partner_created_at,
    partner_country_code,
    all_time_stores,
    all_time_new_payments,
    all_time_new_sellers,
    first_trial_at,
    first_payment_at,
    first_seller_at,
    freemium_stores,
    active_trials,
    active_paying_stores,
    freemium_stores_with_gmv_last_90_days,
    churned_stores,
    -- Current month metrics
    trials_current_month,
    new_payments_current_month,
    new_sellers_current_month,
    gmv_usd_current_month,
    gmv_local_currency_current_month,
    -- Previous month metrics
    trials_previous_month,
    new_payments_previous_month,
    new_sellers_previous_month,
    gmv_usd_previous_month,
    gmv_local_currency_previous_month,
    -- Last quarter metrics
    trials_last_quarter,
    new_payments_last_quarter,
    new_sellers_last_quarter,
    gmv_usd_last_quarter,
    gmv_local_currency_last_quarter,
    -- Last year metrics
    trials_last_year,
    new_payments_last_year,
    new_sellers_last_year,
    gmv_usd_last_year,
    gmv_local_currency_last_year,
    -- Rolling periods
    trials_last_30d,
    new_payments_last_30d,
    new_sellers_last_30d,
    gmv_usd_last_30d,
    gmv_local_currency_last_30d,
    -- Last 90 days metrics
    trials_last_90d,
    new_payments_last_90d,
    new_sellers_last_90d,
    gmv_usd_last_90d,
    gmv_local_currency_last_90d,
    -- Last 180 days metrics
    trials_last_180d,
    new_payments_last_180d,
    new_sellers_last_180d,
    gmv_usd_last_180d,
    gmv_local_currency_last_180d,
    -- Last 365 days metrics
    trials_last_365d,
    new_payments_last_365d,
    new_sellers_last_365d,
    gmv_usd_last_365d,
    gmv_local_currency_last_365d
FROM partners_metrics AS PM