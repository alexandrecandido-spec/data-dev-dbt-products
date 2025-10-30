SELECT
    partner_id,
    country_code,
    CAST(churned_at AS DATE) AS date,
    COUNT(DISTINCT store_id) AS current_churn_stores
FROM {{ ref('_int__affiliates_general_tabla') }}
WHERE churned_at IS NOT NULL
    AND churned_at >= '2023-01-01'
GROUP BY 1, 2, 3
