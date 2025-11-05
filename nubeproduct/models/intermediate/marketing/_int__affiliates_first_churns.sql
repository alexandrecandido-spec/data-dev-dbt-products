-- Owner: YAN GERMANO
SELECT
    partner_id,
    country_code,
    is_store_blocked,
    new_seller,
    CAST(churn_date AS DATE) AS date,
    SUM(churn_30d) AS first_churn_30d,
    SUM(churn_60d) AS first_churn_60d,
    SUM(churn_90d) AS first_churn_90d,
    SUM(churn_post_90d) AS first_churn_post_90d
FROM {{ ref('_int__affiliates_churn_flag') }}
WHERE churn_date >= '2023-01-01'
GROUP BY 1, 2, 3, 4, 5
