{{ config(
    materialized = 'table',
    on_schema_change = 'fail',
    tags = ['midmarket', 'daily-9am']
) }}

WITH base AS (
  SELECT
    CAST(deal_id AS BIGINT)   AS deal_id,
    CAST(store_id AS STRING)  AS store_id,

    TO_DATE(date_entered_prospect_mkt)                AS date_entered_prospect_mkt,
    TO_DATE(date_entered_problem_discovery_sales_dev) AS date_entered_problem_discovery_sales_dev,
    TO_DATE(date_entered_won)                         AS date_entered_won,
    TO_DATE(date_entered_onboarding)                  AS date_entered_onboarding,
    TO_DATE(date_entered_success)                     AS date_entered_success,
    TO_DATE(date_entered_churn_success)               AS date_entered_churn_success,
    TO_DATE(date_entered_warning_success)             AS date_entered_warning_success,
    TO_DATE(date_entered_churn_onboarding)            AS date_entered_churn_onboarding,
    TO_DATE(date_entered_warning_onboarding)          AS date_entered_warning_onboarding,
    CAST(TO_TIMESTAMP(store_info_churned_at) AS DATE) AS store_info_churned_at
  FROM {{ ref('g__aspirational__brands__lifecycle__snapshot') }}
),

derived AS (
  SELECT
    deal_id,
    store_id,
    date_entered_prospect_mkt,
    date_entered_problem_discovery_sales_dev,
    date_entered_won,
    date_entered_onboarding,
    date_entered_success,

    COALESCE(date_entered_warning_success,
             date_entered_warning_onboarding) AS date_warning,

    CASE
      WHEN date_entered_churn_success IS NOT NULL THEN date_entered_churn_success
      WHEN date_entered_churn_success IS NULL
           AND date_entered_churn_onboarding IS NOT NULL
      THEN date_entered_churn_onboarding
      WHEN date_entered_churn_success IS NULL
           AND date_entered_churn_onboarding IS NULL
           AND store_info_churned_at IS NOT NULL
           AND store_info_churned_at >= LEAST(
                COALESCE(date_entered_prospect_mkt, DATE '1900-01-01'),
                COALESCE(date_entered_problem_discovery_sales_dev, DATE '1900-01-01'),
                COALESCE(date_entered_won, DATE '1900-01-01'),
                COALESCE(date_entered_onboarding, DATE '1900-01-01'),
                COALESCE(date_entered_success, DATE '1900-01-01')
           )
      THEN store_info_churned_at
      ELSE NULL
    END AS date_churn
  FROM base
),

normalized AS (
  SELECT
    deal_id,
    store_id,
    TRUNC(date_entered_prospect_mkt, 'MM')                AS date_entered_prospect_mkt,
    TRUNC(date_entered_problem_discovery_sales_dev, 'MM') AS date_entered_problem_discovery_sales_dev,
    TRUNC(date_entered_won, 'MM')                         AS date_entered_won,
    TRUNC(date_entered_onboarding, 'MM')                  AS date_entered_onboarding,
    TRUNC(date_entered_success, 'MM')                     AS date_entered_success,
    TRUNC(date_warning, 'MM')                             AS date_warning,
    TRUNC(date_churn, 'MM')                               AS date_churn
  FROM derived
),

unpivot_long AS (
  SELECT deal_id, store_id, 'date_entered_prospect_mkt' AS attribute, date_entered_prospect_mkt AS date FROM normalized
  UNION ALL SELECT deal_id, store_id, 'date_entered_problem_discovery_sales_dev', date_entered_problem_discovery_sales_dev FROM normalized
  UNION ALL SELECT deal_id, store_id, 'date_entered_won', date_entered_won FROM normalized
  UNION ALL SELECT deal_id, store_id, 'date_entered_onboarding', date_entered_onboarding FROM normalized
  UNION ALL SELECT deal_id, store_id, 'date_entered_success', date_entered_success FROM normalized
  UNION ALL SELECT deal_id, store_id, 'date_warning', date_warning FROM normalized
  UNION ALL SELECT deal_id, store_id, 'date_churn', date_churn FROM normalized
),

flagged AS (
  SELECT
    deal_id,
    store_id,
    date,
    CASE WHEN attribute = 'date_entered_prospect_mkt'                THEN 1 ELSE 0 END AS Prospect_Mkt,
    CASE WHEN attribute = 'date_entered_problem_discovery_sales_dev' THEN 1 ELSE 0 END AS Problem_Discovery,
    CASE WHEN attribute = 'date_entered_won'                         THEN 1 ELSE 0 END AS Won,
    CASE WHEN attribute = 'date_entered_onboarding'                  THEN 1 ELSE 0 END AS Onboarding,
    CASE WHEN attribute = 'date_entered_success'                     THEN 1 ELSE 0 END AS Success,
    CASE WHEN attribute = 'date_warning'                             THEN 1 ELSE 0 END AS Warning,
    CASE WHEN attribute = 'date_churn'                               THEN 1 ELSE 0 END AS Churn
  FROM unpivot_long
  WHERE date IS NOT NULL
),

aggregated AS (
  SELECT
    deal_id,
    store_id,
    date,
    MAX(Prospect_Mkt)      AS Prospect_Mkt,
    MAX(Problem_Discovery) AS Problem_Discovery,
    MAX(Won)               AS Won,
    MAX(Onboarding)        AS Onboarding,
    MAX(Success)           AS Success,
    MAX(Warning)           AS Warning,
    MAX(Churn)             AS Churn
  FROM flagged
  GROUP BY deal_id, store_id, date
),

store_deal_map AS (
  SELECT store_id, MIN(deal_id) AS any_deal_id
  FROM aggregated
  WHERE deal_id IS NOT NULL AND store_id IS NOT NULL
  GROUP BY store_id
),

left_keys AS (
  SELECT store_id FROM store_deal_map
),

-- GMV/ORDERS da LOJA
company AS (
  SELECT
    CAST(c.store_id AS STRING) AS store_id,
    TRUNC(TO_DATE(c.DateMonth), 'MM') AS datemonth_first,
    CAST(c.gmv_usd_on_platform_monthly AS DOUBLE) AS gmv_usd,
    CAST(c.orders_on_platform_monthly  AS BIGINT) AS orders,
    CAST(c.gmv_usd_on_platform_90d     AS DOUBLE) AS gmv_usd_90d
  FROM {{ ref('company_metrics_gmv_and_segments') }} c
  INNER JOIN left_keys k
    ON CAST(c.store_id AS STRING) = k.store_id
),

-- GMV/ORDERS TOTAIS DA NUVEMSHOP por mês
company_total AS (
  SELECT
    TRUNC(TO_DATE(DateMonth), 'MM') AS datemonth_first,
    SUM(gmv_usd_on_platform_monthly) AS gmv_usd_total,
    SUM(orders_on_platform_monthly)  AS orders_total
  FROM {{ ref('company_metrics_gmv_and_segments') }}
  GROUP BY TRUNC(TO_DATE(DateMonth), 'MM')
),

won_map AS (
  SELECT
    store_id,
    MIN(date_entered_won) AS won_month
  FROM normalized
  WHERE date_entered_won IS NOT NULL
  GROUP BY store_id
),

joined AS (
  SELECT
    COALESCE(a.deal_id, m.any_deal_id) AS deal_id,
    COALESCE(a.store_id, c.store_id)   AS store_id,
    COALESCE(a.date, c.datemonth_first) AS datemonth,

    COALESCE(a.Prospect_Mkt,      0) AS Prospect_Mkt,
    COALESCE(a.Problem_Discovery,  0) AS Problem_Discovery,
    COALESCE(a.Won,               0) AS Won,
    COALESCE(a.Onboarding,        0) AS Onboarding,
    COALESCE(a.Success,           0) AS Success,
    COALESCE(a.Warning,           0) AS Warning,
    COALESCE(a.Churn,             0) AS Churn,

    c.gmv_usd,
    c.orders,
    c.gmv_usd_90d
  FROM aggregated a
  FULL OUTER JOIN company c
      ON  a.store_id = c.store_id
      AND a.date     = c.datemonth_first
  LEFT JOIN store_deal_map m
      ON COALESCE(a.store_id, c.store_id) = m.store_id
)

SELECT
  CAST(j.deal_id AS BIGINT) AS deal_id,
  j.store_id,
  CAST(j.datemonth AS DATE) AS datemonth,
  YEAR(j.datemonth)         AS year,
  CAST(j.Prospect_Mkt      AS INT) AS Prospect_Mkt,
  CAST(j.Problem_Discovery AS INT) AS Problem_Discovery,
  CAST(j.Won               AS INT) AS Won,
  CAST(j.Onboarding        AS INT) AS Onboarding,
  CAST(j.Success           AS INT) AS Success,
  CAST(j.Warning           AS INT) AS Warning,
  CAST(j.Churn             AS INT) AS Churn,

  -- GMV/ORDERS da LOJA
  COALESCE(j.gmv_usd, 0.0) AS gmv_usd,
  COALESCE(j.orders,  0)   AS orders,
  CASE WHEN j.Churn   = 1 THEN j.gmv_usd_90d ELSE NULL END AS gmv_churn,
  CASE WHEN j.Warning = 1 THEN j.gmv_usd_90d ELSE NULL END AS gmv_downgrade,

  -- GMV/ORDERS TOTAL da NUVEMSHOP POR MÊS
  t.gmv_usd_total,
  t.orders_total,

  CASE
    WHEN w.won_month IS NOT NULL AND j.datemonth >= w.won_month THEN 'OK'
    ELSE NULL
  END AS status

FROM joined j
LEFT JOIN won_map w
  ON j.store_id = w.store_id
LEFT JOIN company_total t
  ON j.datemonth = t.datemonth_first

WHERE j.datemonth >= DATE '2023-01-01'

ORDER BY j.store_id ASC, j.datemonth ASC