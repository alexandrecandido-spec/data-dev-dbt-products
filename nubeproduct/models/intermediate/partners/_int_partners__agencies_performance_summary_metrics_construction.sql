WITH date_spine AS -- Create a table with the date spine for the snapshot date
(
    SELECT DISTINCT 
        first_day_of_week AS snapshot_date
    FROM {{ ref('dim_calendar') }}
    WHERE date_id BETWEEN '2023-01-01' AND CURRENT_DATE()
),
stores_gmv AS  -- Create a table with the gmv metrics for each partner considering the snapshot date
(
    SELECT 
        partner_id, 
        store_id,
        DS.snapshot_date,
        SUM(CASE WHEN order_date <= DS.snapshot_date THEN gmv_usd_daily ELSE 0 END) AS all_time_gmv,
        SUM(CASE WHEN 
                DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', DS.snapshot_date)
                AND order_date <= DS.snapshot_date
            THEN COALESCE(gmv_usd_daily, 0) 
            ELSE 0 
        END) AS gmv_usd_current_month,
        SUM(CASE WHEN 
                DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', DS.snapshot_date)
                AND order_date <= DS.snapshot_date
            THEN COALESCE(gmv_local_currency_daily, 0) 
            ELSE 0 
        END) AS gmv_local_currency_current_month,
        SUM(CASE WHEN DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', ADD_MONTHS(DS.snapshot_date, -1)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_previous_month,
        SUM(CASE WHEN DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', ADD_MONTHS(DS.snapshot_date, -1)) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_previous_month,
        SUM(CASE WHEN DATE_TRUNC('QUARTER', order_date) = DATE_TRUNC('QUARTER', ADD_MONTHS(DS.snapshot_date, -3)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_quarter,
        SUM(CASE WHEN DATE_TRUNC('QUARTER', order_date) = DATE_TRUNC('QUARTER', ADD_MONTHS(DS.snapshot_date, -3)) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_quarter,
        SUM(CASE WHEN DATE_TRUNC('YEAR', order_date) = DATE_TRUNC('YEAR', ADD_MONTHS(DS.snapshot_date, -12)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_year,
        SUM(CASE WHEN DATE_TRUNC('YEAR', order_date) = DATE_TRUNC('YEAR', ADD_MONTHS(DS.snapshot_date, -12)) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_year,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 30) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_30d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 30) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_30d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 90) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_90d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 90) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_90d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 180) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_180d,    
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 180) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_180d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 365) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_365d,
        SUM(CASE WHEN order_date >= DATE_SUB(DS.snapshot_date, 365) THEN gmv_local_currency_daily ELSE 0 END) AS gmv_local_currency_last_365d
    FROM {{ ref('_int_partners__agencies_stores_metrics_construction') }}
    CROSS JOIN date_spine AS DS
    --WHERE order_date <= DS.snapshot_date
    GROUP BY 1,2,3
),
agencies_stores AS -- Create a table with the stores depending on partners
(
    SELECT 
        store_id,
        created_at,
        first_payment_flg,
        first_seller_at,
        first_payment,
        churned_at,
        payment_lifecycle_status,
        partner_id,
        partner_code,
        partner_name, 
        partner_utm_campaign, 
        partner_created_at,
        partner_country_code
    FROM {{ ref('partners_agencies_affiliates_stores')}}
    WHERE partnership_type = 'store_development'
),
contracts AS    -- Create a table with the historicalcontracts for each store
(
    SELECT
        C.store_id,
        C.plan_id,
        C.type,
        C.start_date,
        C.end_date,
        OGP.grupo AS plan_group
    FROM {{ ref('moltres__contracts') }} AS C
    LEFT JOIN {{ ref('operations_grouping_plans') }} AS OGP
        ON C.plan_id = OGP.plan
    WHERE C.start_date >= '2021-01-01'
),
partners_metrics AS -- Create a table with the metrics for each partner considering the snapshot date
(
    SELECT 
        AS.partner_id,
        AS.partner_code,
        AS.partner_created_at,
        AS.partner_country_code,
        DS.snapshot_date,
        SUM(CASE WHEN created_at <= DS.snapshot_date THEN 1 ELSE 0 END) AS all_time_stores,
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment <= DS.snapshot_date THEN 1 ELSE 0 END) AS all_time_new_payments,
        SUM(CASE WHEN first_seller_at IS NOT NULL AND first_seller_at <= DS.snapshot_date THEN 1 ELSE 0 END) AS all_time_new_sellers,
        MIN(CASE WHEN created_at <= DS.snapshot_date THEN created_at ELSE NULL END) AS first_trial_at,
        MIN(CASE WHEN first_payment_flg = TRUE AND first_payment <= DS.snapshot_date THEN first_payment ELSE NULL END) AS first_payment_at,
        MIN(CASE WHEN first_seller_at IS NOT NULL AND first_seller_at <= DS.snapshot_date THEN first_seller_at ELSE NULL END) AS first_seller_at,
        SUM(CASE WHEN 
            (first_payment IS NULL OR first_payment > DS.snapshot_date)
            AND (churned_at IS NULL OR churned_at > DS.snapshot_date)
            AND C.plan_group = 'freemium' 
            THEN 1 ELSE 0 END) AS freemium_stores,
        SUM(CASE WHEN 
            (first_payment IS NULL OR first_payment > DS.snapshot_date)
            AND (churned_at IS NULL OR churned_at > DS.snapshot_date)
            AND C.plan_group != 'freemium' 
        THEN 1 ELSE 0 END) AS active_trials,
        SUM(CASE WHEN 
            first_payment IS NOT NULL 
            AND first_payment <= DS.snapshot_date 
            AND (churned_at IS NULL OR churned_at > DS.snapshot_date) 
        THEN 1 ELSE 0 END) AS active_paying_stores,
        SUM(CASE WHEN             
            (first_payment IS NULL OR first_payment > DS.snapshot_date)
                AND (churned_at IS NULL OR churned_at > DS.snapshot_date)
                AND C.plan_group = 'freemium'  
                AND gmv_usd_last_90d > 0 
        THEN 1 ELSE 0 END) AS freemium_stores_with_gmv_last_90_days,
        SUM(CASE WHEN churned_at IS NOT NULL AND churned_at <= DS.snapshot_date THEN 1 ELSE 0 END) AS churned_stores,
        -- Current month metrics
        SUM(CASE WHEN 
                DATE_TRUNC('MONTH', created_at) = DATE_TRUNC('MONTH', DS.snapshot_date)
                AND created_at <= DS.snapshot_date
            THEN 1 ELSE 0 END) AS trials_current_month,
        SUM(CASE WHEN 
                first_payment_flg = TRUE 
                AND DATE_TRUNC('MONTH', first_payment) = DATE_TRUNC('MONTH', DS.snapshot_date)
                AND first_payment <= DS.snapshot_date THEN 1 ELSE 0 END) AS new_payments_current_month,
        SUM(CASE WHEN 
                DATE_TRUNC('MONTH', first_seller_at) = DATE_TRUNC('MONTH', DS.snapshot_date)
                AND first_seller_at <= DS.snapshot_date
            THEN 1 ELSE 0 END) AS new_sellers_current_month,
        -- AQUÍ SE SUMA EL GMV DE stores_gmv - con COALESCE para evitar NULLs
        SUM(COALESCE(gmv_usd_current_month, 0)) AS gmv_usd_current_month,
        SUM(COALESCE(gmv_local_currency_current_month, 0)) AS gmv_local_currency_current_month,
        -- Previous month metrics
        SUM(CASE WHEN DATE_TRUNC('MONTH', created_at) = DATE_TRUNC('MONTH', ADD_MONTHS(DS.snapshot_date, -1)) THEN 1 ELSE 0 END) AS trials_previous_month,
        SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('MONTH', first_payment) = DATE_TRUNC('MONTH', ADD_MONTHS(DS.snapshot_date, -1)) THEN 1 ELSE 0 END) AS new_payments_previous_month,
        SUM(CASE WHEN DATE_TRUNC('MONTH', first_seller_at) = DATE_TRUNC('MONTH', ADD_MONTHS(DS.snapshot_date, -1)) THEN 1 ELSE 0 END) AS new_sellers_previous_month,
        SUM(COALESCE(gmv_usd_previous_month, 0)) AS gmv_usd_previous_month,
        SUM(COALESCE(gmv_local_currency_previous_month, 0)) AS gmv_local_currency_previous_month,
        -- Last quarter metrics
        SUM(CASE WHEN DATE_TRUNC('QUARTER', created_at) = DATE_TRUNC('QUARTER', ADD_MONTHS(DS.snapshot_date, -3)) THEN 1 ELSE 0 END) AS trials_last_quarter,
        SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('QUARTER', first_payment) = DATE_TRUNC('QUARTER', ADD_MONTHS(DS.snapshot_date, -3)) THEN 1 ELSE 0 END) AS new_payments_last_quarter,
        SUM(CASE WHEN DATE_TRUNC('QUARTER', first_seller_at) = DATE_TRUNC('QUARTER', ADD_MONTHS(DS.snapshot_date, -3)) THEN 1 ELSE 0 END) AS new_sellers_last_quarter,
        SUM(COALESCE(gmv_usd_last_quarter, 0)) AS gmv_usd_last_quarter,
        SUM(COALESCE(gmv_local_currency_last_quarter, 0)) AS gmv_local_currency_last_quarter,
        -- Last year metrics
        SUM(CASE WHEN DATE_TRUNC('YEAR', created_at) = DATE_TRUNC('YEAR', ADD_MONTHS(DS.snapshot_date, -12)) THEN 1 ELSE 0 END) AS trials_last_year,
        SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('YEAR', first_payment) = DATE_TRUNC('YEAR', ADD_MONTHS(DS.snapshot_date, -12)) THEN 1 ELSE 0 END) AS new_payments_last_year,
        SUM(CASE WHEN DATE_TRUNC('YEAR', first_seller_at) = DATE_TRUNC('YEAR', ADD_MONTHS(DS.snapshot_date, -12)) THEN 1 ELSE 0 END) AS new_sellers_last_year,
        SUM(COALESCE(gmv_usd_last_year, 0)) AS gmv_usd_last_year,
        SUM(COALESCE(gmv_local_currency_last_year, 0)) AS gmv_local_currency_last_year,
        -- Rolling periods
        SUM(CASE WHEN created_at >= DATE_SUB(DS.snapshot_date, 30) THEN 1 ELSE 0 END) AS trials_last_30d, 
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment >= DATE_SUB(DS.snapshot_date, 30) THEN 1 ELSE 0 END) AS new_payments_last_30d,
        SUM(CASE WHEN first_seller_at >= DATE_SUB(DS.snapshot_date, 30) THEN 1 ELSE 0 END) AS new_sellers_last_30d,
        SUM(COALESCE(gmv_usd_last_30d, 0)) AS gmv_usd_last_30d,
        SUM(COALESCE(gmv_local_currency_last_30d, 0)) AS gmv_local_currency_last_30d,
        -- Last 90 days metrics
        SUM(CASE WHEN created_at >= DATE_SUB(DS.snapshot_date, 90) THEN 1 ELSE 0 END) AS trials_last_90d,
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment >= DATE_SUB(DS.snapshot_date, 90) THEN 1 ELSE 0 END) AS new_payments_last_90d,
        SUM(CASE WHEN first_seller_at >= DATE_SUB(DS.snapshot_date, 90) THEN 1 ELSE 0 END) AS new_sellers_last_90d,
        SUM(COALESCE(gmv_usd_last_90d, 0)) AS gmv_usd_last_90d,
        SUM(COALESCE(gmv_local_currency_last_90d, 0)) AS gmv_local_currency_last_90d,
        -- Last 180 days metrics
        SUM(CASE WHEN created_at >= DATE_SUB(DS.snapshot_date, 180) THEN 1 ELSE 0 END) AS trials_last_180d,
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment >= DATE_SUB(DS.snapshot_date, 180) THEN 1 ELSE 0 END) AS new_payments_last_180d,
        SUM(CASE WHEN first_seller_at >= DATE_SUB(DS.snapshot_date, 180) THEN 1 ELSE 0 END) AS new_sellers_last_180d,
        SUM(COALESCE(gmv_usd_last_180d, 0)) AS gmv_usd_last_180d,
        SUM(COALESCE(gmv_local_currency_last_180d, 0)) AS gmv_local_currency_last_180d,
        -- Last 365 days metrics
        SUM(CASE WHEN created_at >= DATE_SUB(DS.snapshot_date, 365) THEN 1 ELSE 0 END) AS trials_last_365d,
        SUM(CASE WHEN first_payment_flg = TRUE AND first_payment >= DATE_SUB(DS.snapshot_date, 365) THEN 1 ELSE 0 END) AS new_payments_last_365d,
        SUM(CASE WHEN first_seller_at >= DATE_SUB(DS.snapshot_date, 365) THEN 1 ELSE 0 END) AS new_sellers_last_365d,
        SUM(COALESCE(gmv_usd_last_365d, 0)) AS gmv_usd_last_365d,
        SUM(COALESCE(gmv_local_currency_last_365d, 0)) AS gmv_local_currency_last_365d
    FROM agencies_stores AS AS
    CROSS JOIN date_spine AS DS
    LEFT JOIN contracts AS C    
        ON AS.store_id = C.store_id
            AND DS.snapshot_date BETWEEN C.start_date AND C.end_date
    LEFT JOIN stores_gmv AS SG
        ON AS.store_id = SG.store_id
            AND DS.snapshot_date = SG.snapshot_date
    WHERE created_at <= DS.snapshot_date
    GROUP BY     
        AS.partner_id,
        AS.partner_code,
        AS.partner_created_at,
        AS.partner_country_code,
        DS.snapshot_date
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