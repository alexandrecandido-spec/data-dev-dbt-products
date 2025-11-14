  SELECT
    pay_header.store_id,
    CAST(MIN(pay_header.paid_at) AS DATE) AS first_payment_enterprise
  FROM {{ source('int_stg_moltres', 'mwp_payment_stores') }} pay_event
  LEFT JOIN {{ ref('operations_grouping_plans') }} pg
    ON pg.plan = pay_event.plan_id
  LEFT JOIN {{ source('int_stg_moltres', 'mwp_payments') }} pay_header
    ON pay_event.payment_id = pay_header.id
  WHERE pg.grupo = 'enterprise'
  GROUP BY pay_header.store_id