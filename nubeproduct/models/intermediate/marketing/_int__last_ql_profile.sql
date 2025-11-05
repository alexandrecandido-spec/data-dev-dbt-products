SELECT 
    store_id,
    profile
FROM (
    SELECT 
        store_id,
        profile,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY store_id
            ORDER BY created_at DESC
        ) AS rn
    FROM {{ source('int_data_predictors', 'marketing_new_payment_predictor_profiles') }}
)
WHERE rn = 1
