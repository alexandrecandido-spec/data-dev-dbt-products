SELECT
    partner_id,
    country_code,
    CAST(created_at AS DATE) AS date,
    COUNT(DISTINCT store_id) AS trials,
    COUNT(DISTINCT CASE WHEN new_payment = 1 THEN store_id ELSE NULL END) AS payments
FROM {{ ref('_int__affiliates_general_tabla') }}
WHERE created_at IS NOT NULL
    AND created_at >= '2023-01-01'
GROUP BY 1, 2, 3
