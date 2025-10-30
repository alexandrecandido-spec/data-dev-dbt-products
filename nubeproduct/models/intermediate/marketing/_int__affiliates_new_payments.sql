SELECT
    partner_id,
    country_code,
    CAST(first_payment AS DATE) AS date,
    COUNT(DISTINCT store_id) AS new_payments
FROM {{ ref('_int__affiliates_general_tabla') }}
WHERE first_payment IS NOT NULL
    AND first_payment >= '2023-01-01'
GROUP BY 1, 2, 3
