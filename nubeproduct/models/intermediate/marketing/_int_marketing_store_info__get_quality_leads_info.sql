SELECT 
si_ql.*
FROM (
  SELECT
    msi.store_id
    , msi.country
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
    , np.predicted_prob AS new_payment_probability
    , tb_cff.cutoff AS prod_cutoff
    , ROW_NUMBER() OVER (PARTITION BY msi.store_id ORDER BY msi.created_at DESC) AS rownumber
  FROM {{ ref('moltres__mwp_store_info') }} msi
  LEFT JOIN {{ ref('_int_marketing__quality_leads') }} np ON msi.store_id = np.store_id
  LEFT JOIN {{ source('int_data_predictors', 'marketing_cutoffs_table') }} tb_cff ON msi.country = tb_cff.country	AND np.model_id = tb_cff.model_id			
                                                                                AND (tb_cff.device = device OR tb_cff.device IS NULL)
) si_ql
WHERE si_ql.rownumber = 1