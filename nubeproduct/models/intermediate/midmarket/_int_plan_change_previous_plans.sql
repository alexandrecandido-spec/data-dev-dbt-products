SELECT 
  store_id,
  year,
  month,
  LAG(store_id_plan_country) OVER (
    PARTITION BY store_id 
    ORDER BY year, month
  ) AS prev_plan,
  
  LAG(
    TO_DATE(
      concat(year, '-', format_string('%02d', month), '-01'), 
      'yyyy-MM-dd'
    )
  ) OVER (
    PARTITION BY store_id 
    ORDER BY year, month
  ) AS previous_date

FROM {{ ref('stg_active_merchants') }}