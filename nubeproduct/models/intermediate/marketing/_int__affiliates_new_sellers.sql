SELECT
    partner_id,
    country_code,
    CAST(first_seller_at AS DATE) AS date,
    COUNT(DISTINCT store_id) AS new_sellers
FROM {{ ref('_int__affiliates_general_tabla') }}
WHERE new_seller = TRUE
    AND first_seller_at >= '2023-01-01'
GROUP BY 1, 2, 3
