WITH first_seller_at_date AS (
  SELECT
    f.store_id, 
    f.year_month_day_code,
    f.first_seller_at
  FROM {{ ref('marketing_first_seller_date') }} f
  WHERE f.first_seller_at IS NOT NULL
)
, store_info_data AS (
  SELECT
    msi.store_id
    , msi.country
    , CAST(date_format(msi.created_at, 'yyyyMMdd') AS INT) AS year_month_day_code
    , DATE(msi.created_at) AS created_at
    , DATE(msi.first_payment) AS first_payment
    , DATE(msi.churned_at) AS churned_at
    , DATE(f.first_seller_at) AS first_seller_at
    , greatest(msi.sys_audit_updated_on, CAST(f.first_seller_at AS TIMESTAMP)) as change_timestamp
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
  LEFT JOIN first_seller_at_date f ON msi.store_id = f.store_id
),
ranked_store_info AS (
  SELECT 
    si.*
    , np.predicted_prob AS new_payment_probability
    , tb_cff.cutoff AS prod_cutoff
    , ROW_NUMBER() OVER (PARTITION BY si.store_id ORDER BY si.created_at DESC) AS rownumber
  FROM store_info_data si
  LEFT JOIN {{ ref('data_predictors__quality_leads') }} np ON si.store_id = np.store_id
  LEFT JOIN {{ source('int_data_predictors', 'marketing_cutoffs_table') }} tb_cff ON si.country = tb_cff.country 
                                                                                    AND np.model_id = tb_cff.model_id 
                                                                                    AND (tb_cff.device = si.device OR tb_cff.device IS NULL)
)

SELECT *
FROM ranked_store_info
WHERE rownumber = 1