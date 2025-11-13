WITH partners_info AS 
(
    SELECT 
        partner_id,
        DATE(partner_created_at) AS partner_created_date,
        IF(DATEDIFF(month, DATE(partner_created_at), CURRENT_DATE()) < 12,'New partner','Established partner') AS partner_age_classification,
        COALESCE(partner_utm_campaign, partner_utm_source, partner_utm_medium, partner_utm_content, 'Unknown') AS partner_origin
    FROM {{ ref('s__general__partners_info__ref')}}
    WHERE has_store_dev_trial = 1
),
calculations AS 
(
    SELECT 
        partner_id,
        MIN(CASE WHEN A.payment_lifecycle_status = 'Paying' AND A.business_unit = 'MM' THEN 'MM' ELSE 'SMB' END) AS partner_business_unit,
        CAST(MAX(CASE WHEN payment_lifecycle_status = 'Paying' THEN 1 ELSE 0 END) AS BOOLEAN) AS active_paying_stores_flg,
        CAST(MAX(CASE WHEN first_payment BETWEEN TRUNC(ADD_MONTHS(CURRENT_DATE,-3), 'month') AND CURRENT_DATE() THEN 1 ELSE 0 END) AS BOOLEAN) AS new_payments_lm3_flg,
        MIN(CASE WHEN tag_acquired_by = 'Partner' THEN DATE(created_at) ELSE NULL END) AS first_store_trial_date,
        MIN(CASE WHEN tag_acquired_by = 'Partner' THEN DATE(first_payment) ELSE NULL END) AS first_store_payment_date,
        MIN(CASE WHEN tag_acquired_by = 'Partner' AND new_seller = TRUE THEN DATE(first_seller_at) ELSE NULL END) AS first_store_seller_date,
        MAX(CASE WHEN tag_acquired_by = 'Partner' THEN DATE(created_at) ELSE NULL END) AS last_store_trial_date,
        MAX(CASE WHEN tag_acquired_by = 'Partner' THEN DATE(first_payment) ELSE NULL END) AS last_store_payment_date,
        MAX(CASE WHEN tag_acquired_by = 'Partner' AND new_seller = TRUE THEN DATE(first_seller_at) ELSE NULL END) AS last_store_seller_date
    FROM  {{ ref('_int_partnerships__partners_stores__table_merchant_domain')}}
    WHERE partnership_type = 'store_development'
    GROUP BY partner_id
)
SELECT * FROM partners_info
LEFT JOIN calculations
    ON partners_info.partner_id = calculations.partner_id