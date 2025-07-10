WITH model_new_payment AS    
(
SELECT
    DISTINCT pp.store_id,
    mv.model_id,
    pp.predicted_prob
FROM  {{source('int_data_predictors', 'marketing_new_payment_predictor')}} AS pp
LEFT JOIN {{source('int_data_predictors', 'marketing_model_version_aux')}} AS mv 
        ON pp.model_id = mv.model_id
        AND pp.created_at BETWEEN mv.became_production - INTERVAL '72 hours' 
        AND COALESCE(mv.left_production, '2999-12-31') - INTERVAL '72 hours' 
WHERE
    mv.became_production IS NOT NULL
),
store_info_data AS (
  SELECT
    msi.store_id
    , msi.country
    , CAST(date_format(msi.created_at, 'yyyyMMdd') AS INT) AS year_month_day_code
    , DATE(msi.created_at) AS created_at
    , DATE(msi.first_payment) AS first_payment
    , DATE(msi.churned_at) AS churned_at
    , CASE 
      WHEN msi.verified = 0 THEN 'undefined'
      WHEN msi.verified = 1 THEN 'desktop'
      WHEN msi.verified = 2 THEN 'app'
      WHEN msi.verified IN (4,5,6) THEN 'mobile'
      ELSE 'tablet'
      END AS device
    , msi.register_url
    , msi.partner_id
    , msi.partnership_type
  FROM {{ ref('moltres__mwp_store_info') }} msi
),
ranked_store_info AS (
  SELECT 
    si.*
    , np.predicted_prob AS new_payment_probability
    , tb_cff.cutoff AS prod_cutoff
    , ROW_NUMBER() OVER (PARTITION BY si.store_id ORDER BY si.created_at DESC) AS rownumber
  FROM store_info_data si
  LEFT JOIN model_new_payment np ON si.store_id = np.store_id
  LEFT JOIN {{ source('int_data_predictors', 'marketing_cutoffs_table') }} tb_cff ON si.country = tb_cff.country 
                                                                                    AND np.model_id = tb_cff.model_id 
                                                                                    AND (tb_cff.device = si.device OR tb_cff.device IS NULL)
)
SELECT 
    store_id,
    prod_cutoff
FROM ranked_store_info
WHERE rownumber = 1