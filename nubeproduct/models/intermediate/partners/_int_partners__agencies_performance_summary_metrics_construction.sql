WITH stores_gmv AS    
(
    SELECT 
        partner_id,
        SUM(gmv_usd_daily) AS all_time_gmv,
        SUM(CASE WHEN DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', CURRENT_DATE()) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_current_month,
        SUM(CASE WHEN DATE_TRUNC('MONTH', order_date) = DATE_TRUNC('MONTH', ADD_MONTHS(CURRENT_DATE(), -1)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_previous_month,
        SUM(CASE WHEN DATE_TRUNC('QUARTER', order_date) = DATE_TRUNC('QUARTER', ADD_MONTHS(CURRENT_DATE(), -3)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_quarter,
        SUM(CASE WHEN DATE_TRUNC('YEAR', order_date) = DATE_TRUNC('YEAR', ADD_MONTHS(CURRENT_DATE(), -12)) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_year,
        SUM(CASE WHEN order_date >= DATE_SUB(CURRENT_DATE(), 30) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_30d,
        SUM(CASE WHEN order_date >= DATE_SUB(CURRENT_DATE(), 90) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_90d,
        SUM(CASE WHEN order_date >= DATE_SUB(CURRENT_DATE(), 180) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_180d,
        SUM(CASE WHEN order_date >= DATE_SUB(CURRENT_DATE(), 365) THEN gmv_usd_daily ELSE 0 END) AS gmv_usd_last_365d,
    FROM    
        (
            SELECT 
                PO.store_id,
                DATE(PO.completed_at) AS order_date,
                SUM(PO.total_in_local_currency) AS gmv_local_currency_daily,
                SUM(PO.total_in_usd) AS gmv_usd_daily,
                COUNT(PO.id) AS orders_daily,
                PS.partner_id
            FROM {{ ref('company_metrics_paid_orders') }} AS PO
            INNER JOIN {{ ref('partners_agencies_affiliates_stores') }} AS PS
                ON PO.store_id = PS.store_id
            WHERE PO.completed_at IS NOT NULL
                AND PO.platform_type = 'on'
                AND PS.partnership_type = 'store_development'
            GROUP BY 
                PO.store_id, 
                DATE(PO.completed_at),
                PS.partner_id
        )
    GROUP BY 1
),
agencies_stores AS
(
    SELECT 
        store_id,
        created_at,
        first_payment_flg,
        first_seller_at,
        first_payment,
        payment_lifecycle_status,
        partner_id,
        partner_code,
        partner_name, 
        utm_campaign, 
        partner_created_at,
        partner_country_code
    FROM {{ ref('partners_agencies_affiliates_stores')}}
    WHERE partnership_type = 'store_development'
)
SELECT 
    partner_id,
    partner_code,
    partner_name, 
    utm_campaign, 
    partner_created_at,
    partner_country_code,
    COUNT(*) AS all_time_stores,
    SUM(CASE WHEN first_payment_flg = TRUE THEN 1 ELSE 0 END) AS all_time_new_payments,
    SUM(CASE WHEN first_seller_at IS NOT NULL THEN 1 ELSE 0 END) AS all_time_new_sellers,
    MIN(created_at) AS first_trial_at,
    MIN(CASE WHEN first_payment_flg = TRUE THEN first_payment ELSE NULL END) AS first_payment_at,
    MIN(CASE WHEN first_seller_at IS NOT NULL THEN first_seller_at ELSE NULL END) AS first_seller_at,
    SUM(CASE WHEN payment_lifecycle_status = 'Freemium' THEN 1 ELSE 0 END) AS freemium_stores,
    SUM(CASE WHEN payment_lifecycle_status = 'Trial' THEN 1 ELSE 0 END) AS active_trials,
    SUM(CASE WHEN payment_lifecycle_status = 'Paying' THEN 1 ELSE 0 END) AS active_paying_stores,
    SUM(CASE WHEN payment_lifecycle_status = 'Freemium' AND gmv_usd_last_90d > 0 THEN 1 ELSE 0 END) AS freemium_stores_with_gmv_last_90_days,
    SUM(CASE WHEN payment_lifecycle_status = 'Churned' THEN 1 ELSE 0 END) AS churned_stores,
    -- Current month metrics
    SUM(CASE WHEN DATE_TRUNC('MONTH', created_at) = DATE_TRUNC('MONTH', CURRENT_DATE()) THEN 1 ELSE 0 END) AS trials_current_month,
    SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('MONTH', first_payment) = DATE_TRUNC('MONTH', CURRENT_DATE()) THEN 1 ELSE 0 END) AS new_payments_current_month,
    SUM(CASE WHEN DATE_TRUNC('MONTH', first_seller_at) = DATE_TRUNC('MONTH', CURRENT_DATE()) THEN 1 ELSE 0 END) AS new_sellers_current_month,
    SG.gmv_usd_current_month,
    -- Previous month metrics
    SUM(CASE WHEN DATE_TRUNC('MONTH', created_at) = DATE_TRUNC('MONTH', ADD_MONTHS(CURRENT_DATE(), -1)) THEN 1 ELSE 0 END) AS trials_previous_month,
    SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('MONTH', first_payment) = DATE_TRUNC('MONTH', ADD_MONTHS(CURRENT_DATE(), -1)) THEN 1 ELSE 0 END) AS new_payments_previous_month,
    SUM(CASE WHEN DATE_TRUNC('MONTH', first_seller_at) = DATE_TRUNC('MONTH', ADD_MONTHS(CURRENT_DATE(), -1)) THEN 1 ELSE 0 END) AS new_sellers_previous_month,
    SG.gmv_usd_previous_month,
    -- Last quarter metrics
    SUM(CASE WHEN DATE_TRUNC('QUARTER', created_at) = DATE_TRUNC('QUARTER', ADD_MONTHS(CURRENT_DATE(), -3)) THEN 1 ELSE 0 END) AS trials_last_quarter,
    SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('QUARTER', first_payment) = DATE_TRUNC('QUARTER', ADD_MONTHS(CURRENT_DATE(), -3)) THEN 1 ELSE 0 END) AS new_payments_last_quarter,
    SUM(CASE WHEN DATE_TRUNC('QUARTER', first_seller_at) = DATE_TRUNC('QUARTER', ADD_MONTHS(CURRENT_DATE(), -3)) THEN 1 ELSE 0 END) AS new_sellers_last_quarter,
    SG.gmv_usd_last_quarter,
    -- Last year metrics
    SUM(CASE WHEN DATE_TRUNC('YEAR', created_at) = DATE_TRUNC('YEAR', ADD_MONTHS(CURRENT_DATE(), -12)) THEN 1 ELSE 0 END) AS trials_last_year,
    SUM(CASE WHEN first_payment_flg = TRUE AND DATE_TRUNC('YEAR', first_payment) = DATE_TRUNC('YEAR', ADD_MONTHS(CURRENT_DATE(), -12)) THEN 1 ELSE 0 END) AS new_payments_last_year,
    SUM(CASE WHEN DATE_TRUNC('YEAR', first_seller_at) = DATE_TRUNC('YEAR', ADD_MONTHS(CURRENT_DATE(), -12)) THEN 1 ELSE 0 END) AS new_sellers_last_year,
    SG.gmv_usd_last_year,
    -- Rolling periods
    SUM(CASE WHEN created_at >= DATE_SUB(CURRENT_DATE(), 30) THEN 1 ELSE 0 END) AS trials_last_30d,
    SUM(CASE WHEN first_payment_flg = TRUE AND first_payment >= DATE_SUB(CURRENT_DATE(), 30) THEN 1 ELSE 0 END) AS new_payments_last_30d,
    SG.gmv_usd_last_30d,
    -- Last 90 days metrics
    SUM(CASE WHEN created_at >= DATE_SUB(CURRENT_DATE(), 90) THEN 1 ELSE 0 END) AS trials_last_90d,
    SUM(CASE WHEN first_payment_flg = TRUE AND first_payment >= DATE_SUB(CURRENT_DATE(), 90) THEN 1 ELSE 0 END) AS new_payments_last_90d,
    SG.gmv_usd_last_90d,
    -- Last 180 days metrics
    SUM(CASE WHEN created_at >= DATE_SUB(CURRENT_DATE(), 180) THEN 1 ELSE 0 END) AS trials_last_180d,
    SUM(CASE WHEN first_payment_flg = TRUE AND first_payment >= DATE_SUB(CURRENT_DATE(), 180) THEN 1 ELSE 0 END) AS new_payments_last_180d,
    SG.gmv_usd_last_180d,
    -- Last 365 days metrics
    SUM(CASE WHEN created_at >= DATE_SUB(CURRENT_DATE(), 365) THEN 1 ELSE 0 END) AS trials_last_365d,
    SUM(CASE WHEN first_payment_flg = TRUE AND first_payment >= DATE_SUB(CURRENT_DATE(), 365) THEN 1 ELSE 0 END) AS new_payments_last_365d,
    SG.gmv_usd_last_365d
FROM agencies_stores AS AS
LEFT JOIN stores_gmv AS SG
    ON AS.partner_id = SG.partner_id
GROUP BY     
    AS.partner_id,
    AS.partner_code,
    AS.partner_name, 
    AS.utm_campaign, 
    AS.partner_created_at,
    AS.partner_country_code
