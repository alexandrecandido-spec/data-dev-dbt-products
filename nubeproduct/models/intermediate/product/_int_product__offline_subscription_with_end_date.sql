-- gets the next start date for a merchant, if exists
WITH subscriptions_with_lag AS (
SELECT
    subscription_id
    , store_id
    , plan_name
    , plan_type
    , start_date
    , end_date
    , cpt
    , subscription_updated_on
    , store_updated_on
    , LAG(start_date) OVER (PARTITION BY store_id ORDER BY DATE(start_date) DESC, start_date DESC) AS next_start_date
FROM 
    {{ ref('_int_product__offline_subscription_with_plan_type') }}
)

-- adjusts the end date of each plan
, subscriptions_with_effective_end_date AS (
SELECT
    *
    , CASE  WHEN end_date IS NULL AND next_start_date IS NOT NULL THEN next_start_date - INTERVAL 1 SECOND
            WHEN next_start_date < end_date THEN next_start_date - INTERVAL 1 SECOND
            WHEN end_date IS NULL AND next_start_date IS NULL THEN CAST('9999-12-31 23:59:59' AS TIMESTAMP)
            ELSE end_date
            END AS effective_end_date
FROM
    subscriptions_with_lag
)

-- calculates the bill cycle for the plan
, final_with_bill_cycle AS (
SELECT
    subscription_id
    , store_id
    , plan_name
    , plan_type
    , start_date
    , effective_end_date
    , cpt
    , subscription_updated_on
    , store_updated_on
    , GREATEST(1, CEIL(DATEDIFF(effective_end_date, start_date) / 30.0)) AS bill_cycle
FROM 
    subscriptions_with_effective_end_date
)

-- final info
SELECT 
    *
FROM 
    final_with_bill_cycle
