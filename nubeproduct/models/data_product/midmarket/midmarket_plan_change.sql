{{
  config(
    materialized = 'incremental',
    unique_key = ['store_id', 'date'],
    on_schema_change = 'fail',
    tags = ['weekly-monday-10am']
  )
}}

WITH base AS (
  SELECT 
    raw_query.*,
    ROW_NUMBER() OVER (ORDER BY store_id, year, month) AS row_id
  FROM {{ ref('_int_plan_change_raw') }} raw_query
  {% if is_incremental() %}
    WHERE date >= date_trunc('month', current_date() - interval '1 month')
  {% endif %}
),

mes_seguinte AS (
  SELECT
    prev.row_id AS prev_row_id,
    nxt.row_id AS next_row_id
  FROM base prev
  LEFT JOIN base nxt 
    ON prev.store_id = nxt.store_id 
    AND add_months(prev.date, 1) = nxt.date
  WHERE
    prev.plan_change_escala_numeric_indicator = 1
    OR prev.plan_change_escala = 'Escala'
    OR prev.plan_change_enterprise_numeric_indicator = 1
    OR prev.plan_change_enterprise = 'Evolución'
),

churns_implicitos AS (
  SELECT
    b.store_id,
    CAST(year(add_months(b.date, 1)) AS int) AS year,
    CAST(month(add_months(b.date, 1)) AS int) AS month,
    b.country,
    b.domain,
    add_months(b.date, 1) AS date,
    b.plan,
    b.plan_level,
    b.previous_plan,
    b.previous_plan_level,
    b.previous_date,
    b.current_plan,
    b.created_at,
    b.first_payment,
    b.first_payment_escala,
    b.first_payment_enterprise,
    b.churned_at,
    CASE WHEN b.is_escala_interest = 1 THEN 'Churn' ELSE '-' END AS plan_change_escala,
    CASE WHEN b.is_escala_interest = 1 THEN -1 ELSE 0 END AS plan_change_escala_numeric_indicator,
    CASE WHEN b.is_enterprise_interest = 1 THEN 'Churn' ELSE '-' END AS plan_change_enterprise,
    CASE WHEN b.is_enterprise_interest = 1 THEN -1 ELSE 0 END AS plan_change_enterprise_numeric_indicator,
    b.is_escala_interest,
    b.is_enterprise_interest,
    b.sys_audit_created_on,
    b.sys_audit_created_by,
    b.sys_audit_updated_on,
    b.sys_audit_updated_by
  FROM mes_seguinte m
  JOIN base b ON b.row_id = m.prev_row_id
  WHERE m.next_row_id IS NULL
),

base_final AS (
  SELECT * FROM {{ ref('_int_plan_change_raw') }}
  {% if is_incremental() %}
    WHERE date >= date_trunc('month', current_date() - interval '1 month')
  {% endif %}

  UNION ALL

  SELECT * FROM churns_implicitos
)

SELECT *
FROM base_final
WHERE date <= date_trunc('month', current_date())
ORDER BY store_id, year, month