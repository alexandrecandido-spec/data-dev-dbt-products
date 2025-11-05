-- Temporary table to flag churns for affiliates! This table is used to calculate the first churns for affiliates.
-- Owner: YAN GERMANO

WITH churns AS (
    SELECT 
        AGT.partner_id,
        AGT.country_code,
        AGT.store_id,
        AGT.is_store_blocked,
        AGT.new_seller,
        CAST(CM.store_first_payment AS DATE) AS first_payment,
        MIN(CAST(CM.date AS DATE)) AS churn_date
    FROM {{ ref('_int__affiliates_general_tabla') }} AS AGT 
    INNER JOIN {{ source('int_finance', 'churns_merchants') }} AS CM
        ON AGT.store_id = CM.store_id
    WHERE CM.store_first_payment IS NOT NULL
        AND CM.date >= CM.store_first_payment
    GROUP BY 1,2,3,4,5,6
)

SELECT 
    partner_id,
    country_code,   
    store_id,
    is_store_blocked,
    first_payment,
    churn_date,
    new_seller,
    FLOOR(MONTHS_BETWEEN(churn_date, first_payment)) AS months_to_first_churn,
    CASE WHEN DATEDIFF(churn_date, first_payment) <= 30 THEN 1 ELSE 0 END AS churn_30d,
    CASE WHEN DATEDIFF(churn_date, first_payment) BETWEEN 31 AND 60 THEN 1 ELSE 0 END AS churn_60d,
    CASE WHEN DATEDIFF(churn_date, first_payment) BETWEEN 61 AND 90 THEN 1 ELSE 0 END AS churn_90d,
    CASE WHEN DATEDIFF(churn_date, first_payment) >= 91 THEN 1 ELSE 0 END AS churn_post_90d
FROM churns
