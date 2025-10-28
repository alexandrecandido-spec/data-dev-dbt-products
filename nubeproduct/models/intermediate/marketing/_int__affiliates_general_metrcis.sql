WITH trial AS (
  SELECT
    partner_id,
    country_code,
    CAST(created_at AS DATE) AS date,
    COUNT(DISTINCT store_id) AS trial
  FROM {{ ref('_int_affiliates_general_tabla') }}
  GROUP BY 1,2,3
),

nps AS (
  SELECT
    partner_id,
    country_code,
    CAST(first_payment AS DATE) AS date,
    COUNT(DISTINCT store_id) AS new_payments
  FROM {{ ref('_int_affiliates_general_tabla') }}
  WHERE first_payment IS NOT NULL
  GROUP BY 1,2,3
),

first_seller AS (   
  SELECT
    partner_id,
    country_code,
    CAST(first_seller_at AS DATE) AS date,
    COUNT(DISTINCT store_id) AS new_sellers
    FROM {{ ref('_int_affiliates_general_tabla') }}
  WHERE new_seller = TRUE
  GROUP BY 1,2,3
),

churned AS (
  SELECT
    partner_id,
    country_code,
    CAST(churned_at AS DATE) AS date,
    COUNT(DISTINCT store_id) AS churned_stores
  FROM {{ ref('_int_affiliates_general_tabla') }}
  WHERE churned_at IS NOT NULL
  GROUP BY 1,2,3
),

joined AS (
  SELECT
    COALESCE(t.partner_id, n.partner_id, f.partner_id) AS partner_id,
    COALESCE(t.country_code, n.country_code, f.country_code) AS country_code,
    COALESCE(t.date, n.date, f.date) AS date,
    COALESCE(t.trial, 0) AS trial,
    COALESCE(n.new_payments, 0) AS new_payments,
    COALESCE(f.new_sellers, 0) AS new_sellers
  FROM trial t
  FULL JOIN nps n
    ON t.partner_id = n.partner_id
    AND t.country_code = n.country_code
    AND t.date = n.date
  FULL JOIN first_seller f
    ON COALESCE(t.partner_id, n.partner_id) = f.partner_id
    AND COALESCE(t.country_code, n.country_code) = f.country_code
    AND COALESCE(t.date, n.date) = f.date
)
SELECT *
FROM joined