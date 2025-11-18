WITH partners_info AS 
(
    SELECT 
        partner_id,
        DATE(partner_created_at) AS partner_created_date,
        IF(DATEDIFF(month, DATE(partner_created_at), CURRENT_DATE()) < 12,'New partner','Established partner') AS partner_age_classification,
        COALESCE(partner_utm_campaign, partner_utm_source, partner_utm_medium, partner_utm_content, 'Unknown') AS partner_origin,
        sys_audit_updated_on AS partner_info_change_timestamp
    FROM {{ ref('s__general__partners_info__ref')}}
    WHERE has_store_dev_trial = 1
),
calculations AS 
(
    SELECT 
        partner_id,
        MAX(table_merchant_change_timestamp) AS table_merchant_change_timestamp,
        MIN(CASE WHEN payment_lifecycle_status = 'Paying' AND business_unit = 'MM' THEN 'MM' ELSE 'SMB' END) AS partner_business_unit,
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
),
partners_levels AS 
(
    SELECT 
        partner_id,
        partner_level, 
        program_levels_change_timestamp 
    FROM 
    (
    SELECT 
        ROW_NUMBER() OVER(PARTITION BY partner_id ORDER BY snapshot_date DESC) AS RN,
        partner_id,
        partner_level,
        sys_audit_updated_on AS program_levels_change_timestamp
    FROM {{ ref('s__agencies__program_levels__scd')}}
    )
    WHERE RN = 1
)
SELECT 
    PI.* EXCEPT(PI.partner_info_change_timestamp),
    C.* EXCEPT(C.partner_id, C.table_merchant_change_timestamp),
    PL.* EXCEPT(PL.partner_id, PL.program_levels_change_timestamp),
    CASE 
        WHEN first_store_trial_date IS NOT NULL 
            AND DATE_TRUNC('MONTH', first_store_trial_date) = DATE_TRUNC('MONTH', ADD_MONTHS(CURRENT_DATE(), -1)) 
        THEN 'Pre-new'
        WHEN first_store_payment_date IS NOT NULL 
            AND DATE_TRUNC('MONTH', first_store_payment_date) = DATE_TRUNC('MONTH', ADD_MONTHS(CURRENT_DATE(), -1)) 
        THEN 'New'
    ELSE 'Established'
    END AS lifecycle_status,
    GREATEST(PI.partner_info_change_timestamp, C.table_merchant_change_timestamp, PL.program_levels_change_timestamp) AS agencies_info_change_timestamp
FROM partners_info PI
LEFT JOIN calculations C
    ON PI.partner_id = C.partner_id
LEFT JOIN partners_levels PL
    ON PI.partner_id = PL.partner_id