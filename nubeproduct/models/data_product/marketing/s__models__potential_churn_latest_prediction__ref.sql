/*
  Silver data product: Latest Potential Churn prediction per store
Description: This model selects the most recent churn prediction for each store
Owner: ianca.leite@nuvemshop.com.br
Domain: marketing

Spec: This model selects the most recent churn prediction for each store from the monthly snapshot model: marketing__models__churn_predictor__snapshot_monthly
      Logic: For each store_id, order predictions by:
              1) snapshot_month_end (latest month first)
              2) prediction_timestamp (latest run first)
             Keep only the top-ranked row (rn = 1) per store.
*/

{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        tags = ['monthly-2nd-10AM']
    )
}}

WITH base AS (
    SELECT
        store_id,
        country,
        snapshot_month_end,
        prediction_timestamp,
        CASE 
            WHEN life_stage = 'A1' THEN '0–30d'
            WHEN life_stage = 'A2' THEN '1–6m'
            WHEN life_stage = 'B'  THEN '6–12m'
            WHEN life_stage = 'C'  THEN '12m+'
            ELSE life_stage
        END AS life_stage_bucket,
        profile,
        probability, 
        prediction 
        -- we deliberately do not bring all columns to keep it business-focused, 
        -- currently only the ones used in the hubspot company variables
    FROM {{ ref('marketing__models__churn_predictor__snapshot_monthly') }}
),

ranked AS (
    SELECT
        base.*,
        ROW_NUMBER() OVER (
            PARTITION BY store_id
            ORDER BY snapshot_month_end DESC, prediction_timestamp DESC
        ) AS rn
    FROM base
)

SELECT
    store_id,
    country,
    snapshot_month_end,
    life_stage_bucket,
    profile,
    probability,
    prediction
FROM ranked
WHERE rn = 1
