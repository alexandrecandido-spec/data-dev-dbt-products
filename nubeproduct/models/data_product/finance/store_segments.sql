SELECT 
    datemonth,
    store_id,
    country,
    currency,
    created_at,
    proportional_segment,
    is_paying_merchant,
    orders_general_month,
    gmv_general_month AS gmv_usd_last_month_closed,
    gmv_local_general_month AS gmv_local_currency_last_month_closed,
    orders_general_90d,
    CASE
        WHEN orders_general_90d * proportional > 1500 THEN 'top-seller'
        WHEN orders_general_90d * proportional BETWEEN 751 AND 1500 THEN 'large-seller'
        WHEN orders_general_90d * proportional BETWEEN 151 AND 750 THEN 'medium-seller'
        WHEN orders_general_90d * proportional BETWEEN 31 AND 150 THEN 'small-seller'
        WHEN orders_general_90d * proportional BETWEEN 7 AND 30 THEN 'tiny-seller'
        WHEN orders_general_90d * proportional BETWEEN 1 AND 6 THEN 'struggling-seller'
        ELSE 'no-seller'
    END AS segment,
    orders_on_platform_month,
    gmv_on_platform_month AS gmv_usd_on_platform_last_month_closed,
    gmv_local_on_platform_month AS gmv_local_currency_on_platform_last_month_closed,
    orders_on_platform_90d,
    CASE
        WHEN orders_on_platform_90d * proportional > 1500 THEN 'top-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 751 AND 1500 THEN 'large-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 151 AND 750 THEN 'medium-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 31 AND 150 THEN 'small-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 7 AND 30 THEN 'tiny-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 1 AND 6 THEN 'struggling-seller'
        ELSE 'no-seller'
    END AS segment_on_platform,
    orders_off_platform_month,
    gmv_off_platform_month AS gmv_usd_off_platform_last_month_closed,
    gmv_local_off_platform_month AS gmv_local_currency_off_platform_last_month_closed,
    orders_off_platform_90d,
    CASE
        WHEN orders_off_platform_90d * proportional > 1500 THEN 'top-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 751 AND 1500 THEN 'large-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 151 AND 750 THEN 'medium-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 31 AND 150 THEN 'small-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 7 AND 30 THEN 'tiny-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 1 AND 6 THEN 'struggling-seller'
        ELSE 'no-seller'
    END AS segment_off_platform
FROM {{ ref('_int_store_segments') }}
WHERE is_paying_merchant = 1 OR (is_paying_merchant=0 AND orders_general_90d>0)