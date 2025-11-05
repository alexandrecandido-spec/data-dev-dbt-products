-- Owner: YAN GERMANO
SELECT
    partner_id,
    country_code,
    is_store_blocked,
    new_seller,
    CAST(created_at AS DATE) AS date,
    COUNT(DISTINCT store_id) AS qls
FROM {{ ref('_int__affiliates_general_tabla') }}
WHERE is_quality_lead = 1
    AND created_at >= '2023-01-01'
GROUP BY 1, 2, 3, 4, 5