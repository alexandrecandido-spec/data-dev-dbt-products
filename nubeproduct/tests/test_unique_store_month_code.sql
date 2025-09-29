SELECT
  store_id,
  month_end,
  year_month_code,
  COUNT(*) AS count
FROM {{ ref('data_predictors__churn_predictions') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1