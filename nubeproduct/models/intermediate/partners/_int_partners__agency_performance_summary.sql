SELECT 
    partner_id,
    partner_code,
    partner_name, 
    utm_campaign, 
    partner_created_at,
    partner_email,
    partner_phone_number,
    partner_country_code,
    COUNT(*) AS all_time_stores,
    SUM(CASE WHEN first_payment_flg = TRUE THEN 1 ELSE 0 END) AS all_time_new_payments,
    MIN(created_at) AS first_trial_at,
    MIN(first_payment) AS first_payment_at,
    SUM(CASE WHEN payment_lifecycle_status = 'Freemium' THEN 1 ELSE 0 END) AS active_freemium_stores,
    SUM(CASE WHEN payment_lifecycle_status = 'Trial' THEN 1 ELSE 0 END) AS active_trials,
    SUM(CASE WHEN payment_lifecycle_status = 'Paying' THEN 1 ELSE 0 END) AS active_paying_stores,
    SUM(CASE WHEN payment_lifecycle_status = 'Churned' THEN 1 ELSE 0 END) AS churned_stores,
FROM {{ ref('partners_agencies_affiliates_stores')}}
WHERE partnership_type = 'store_development'
