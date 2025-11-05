-- Owner: YAN GERMANO
SELECT
    partner_id,
    country_code,
    is_store_blocked,
    new_seller,
    CAST(first_payment AS DATE) AS date,
    COUNT(DISTINCT CASE WHEN new_payment = 1 THEN store_id ELSE NULL END) AS new_payments,
    COUNT(DISTINCT CASE WHEN new_seller = TRUE THEN store_id ELSE NULL END) AS new_sellers_first_payment
FROM {{ ref('_int__affiliates_general_tabla') }}
WHERE first_payment >= '2020-01-01'
GROUP BY 1, 2, 3, 4, 5
