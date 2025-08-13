SELECT
  am.store_id,
  am.year,
  am.month,
  msi.country,
  msi.domain,
  TO_DATE(concat(am.year, '-', format_string('%02d', am.month), '-01'), 'yyyy-MM-dd') AS date,
  pc.grupo AS plan,
  CASE
    WHEN pc.grupo = 'freemium' THEN 0
    WHEN pc.grupo = 'plan-a' THEN 1
    WHEN pc.grupo = 'plan-b' THEN 2
    WHEN pc.grupo = 'plan-c' THEN 3
    WHEN pc.grupo = 'enterprise' THEN 4
    ELSE -2
  END AS plan_level,

  COALESCE(prev_pc.grupo, luc.contract_type) AS previous_plan,

  CASE
    WHEN prev_pc.grupo = 'freemium' OR (prev_pc.grupo IS NULL AND luc.contract_type = 'freemium') THEN 0
    WHEN prev_pc.grupo IS NULL AND luc.contract_type = 'trial' THEN -1
    WHEN prev_pc.grupo = 'plan-a' THEN 1
    WHEN prev_pc.grupo = 'plan-b' THEN 2
    WHEN prev_pc.grupo = 'plan-c' THEN 3
    WHEN prev_pc.grupo = 'enterprise' THEN 4
    WHEN prev_pc.grupo IS NOT NULL THEN -2
    ELSE NULL
  END AS previous_plan_level,
  pp.previous_date,
  cc.grupo AS current_plan,
  CAST(msi.created_at AS date) AS created_at,
  CAST(msi.first_payment AS date) AS first_payment,
  fpe.first_payment_escala,
  fee.first_payment_enterprise,
  CAST(msi.churned_at AS date) AS churned_at,

  -- Escala logic
  CASE
    WHEN date_trunc('month', CAST(churned_at AS date)) = date
         AND (plan_level = 3 OR previous_plan_level = 3)
         AND fpe.first_payment_escala IS NOT NULL
         AND date_trunc('month', fpe.first_payment_escala) < date
      THEN 'Churn'
    WHEN plan_level = 3
         AND (fpe.first_payment_escala IS NULL OR date_trunc('month', fpe.first_payment_escala) > date)
      THEN 'Trial Escala'
    WHEN plan_level = 3
         AND date_trunc('month', fpe.first_payment_escala) = date
         AND date_trunc('month', CAST(churned_at AS date)) = date
      THEN 'Upgrade/Downgrade to Escala & Churn'
    WHEN plan_level = 3
         AND date_trunc('month', fpe.first_payment_escala) = date
         AND date_trunc('month', CAST(msi.created_at AS date)) = date
      THEN CASE
             WHEN date_trunc('month', CAST(churned_at AS date)) = date THEN 'New Payment & Churn'
             ELSE 'New Payment'
           END
    WHEN plan_level = 3
         AND (previous_plan_level != 3 OR previous_plan_level IS NULL)
         AND fpe.first_payment_escala >= CAST(msi.first_payment AS date)
      THEN CASE previous_plan_level
             WHEN -2 THEN 'Upgrade from other plans'
             WHEN -1 THEN 'Upgrade from trial'
             WHEN 0 THEN 'Upgrade from freemium'
             WHEN 1 THEN 'Upgrade from paying plans'
             WHEN 2 THEN 'Upgrade from paying plans'
             WHEN 4 THEN 'Downgrade from Evolución'
           END
    WHEN plan_level != 3
         AND previous_plan_level = 3
         AND fpe.first_payment_escala < date
      THEN CASE
             WHEN add_months(date, -1) > previous_date THEN '-'
             ELSE CASE plan_level
                    WHEN -2 THEN 'Downgrade to other plans'
                    WHEN 0 THEN 'Downgrade to freemium'
                    WHEN 1 THEN 'Downgrade to paying plans'
                    WHEN 2 THEN 'Downgrade to paying plans'
                    WHEN 4 THEN 'Upgrade to Evolución'
                    ELSE '-'
                  END
           END
    WHEN plan_level = 3
         AND previous_plan_level = 3
         AND date > fpe.first_payment_escala
      THEN CASE
             WHEN add_months(date, -1) > previous_date OR churned_at < date THEN 'Phoenix'
             ELSE 'Escala'
           END
    WHEN plan_level = 3
         AND previous_plan_level = 3
         AND date = date_trunc('month', fpe.first_payment_escala)
      THEN 'Upgrade from trial'
    ELSE '-'
  END AS plan_change_escala,

  CASE
    WHEN plan_change_escala LIKE '%& Churn' THEN -1
    WHEN plan_change_escala = 'Churn' THEN -1
    WHEN plan_change_escala = 'Saiu do Trial Escala' THEN 0
    WHEN plan_change_escala = 'Downgrade to freemium' THEN -1
    WHEN plan_change_escala = 'Downgrade to other plans' THEN -1
    WHEN plan_change_escala = 'Downgrade to paying plans' THEN -1
    WHEN plan_change_escala = 'Upgrade to Evolución' THEN -1
    WHEN plan_change_escala = 'New Payment' THEN 1
    WHEN plan_change_escala = 'Upgrade from trial' THEN 1
    WHEN plan_change_escala = 'Upgrade from freemium' THEN 1
    WHEN plan_change_escala = 'Upgrade from other plans' THEN 1
    WHEN plan_change_escala = 'Upgrade from paying plans' THEN 1
    WHEN plan_change_escala = 'Downgrade from Evolución' THEN 1
    WHEN plan_change_escala = 'Phoenix' THEN 1
    WHEN plan_change_escala = 'Trial Escala' THEN 0
    WHEN plan_change_escala = 'Escala' THEN 0
    ELSE 0
  END AS plan_change_escala_numeric_indicator,

  -- Enterprise logic
  CASE
    WHEN date_trunc('month', CAST(churned_at AS date)) = date
        AND plan_level = 4
      THEN 'Churn'
    WHEN plan_level = 4 AND previous_plan_level <> 4
        AND date_trunc('month', CAST(msi.created_at AS date)) = date
      THEN CASE
            WHEN date_trunc('month', CAST(churned_at AS date)) = date THEN 'New Payment & Churn'
            ELSE 'New Payment'
          END
    WHEN plan_level = 4
        AND (previous_plan_level != 4 OR previous_plan_level IS NULL)
      THEN CASE previous_plan_level
            WHEN -2 THEN 'Upgrade from other plans'
            WHEN -1 THEN 'Upgrade from trial'
            WHEN 0 THEN 'Upgrade from freemium'
            WHEN 1 THEN 'Upgrade from paying plans'
            WHEN 2 THEN 'Upgrade from paying plans'
            WHEN 3 THEN 'Upgrade from Escala'
          END
    WHEN plan_level = 4
        AND previous_plan_level = 4
      THEN CASE
            WHEN add_months(date, -1) > previous_date OR churned_at < date THEN 'Phoenix'
            ELSE 'Evolución'
          END
    WHEN plan_level != 4
        AND previous_plan_level = 4
      THEN CASE
            WHEN add_months(date, -1) > previous_date THEN '-'
            ELSE CASE plan_level
                    WHEN -2 THEN 'Downgrade to other plans'
                    WHEN 0 THEN 'Downgrade to freemium'
                    WHEN 1 THEN 'Downgrade to paying plans'
                    WHEN 2 THEN 'Downgrade to paying plans'
                    WHEN 3 THEN 'Downgrade to Escala'
                    ELSE '-'
                  END
          END
    ELSE '-'
  END AS plan_change_enterprise,

  CASE
    WHEN plan_change_enterprise LIKE '%& Churn' THEN -1
    WHEN plan_change_enterprise = 'Churn' THEN -1
    WHEN plan_change_enterprise = 'Downgrade to other plans' THEN -1
    WHEN plan_change_enterprise = 'Downgrade to freemium' THEN -1
    WHEN plan_change_enterprise = 'Downgrade to paying plans' THEN -1
    WHEN plan_change_enterprise = 'Downgrade to Escala' THEN -1
    WHEN plan_change_enterprise = 'New Payment' THEN 1
    WHEN plan_change_enterprise = 'Upgrade from trial' THEN 1
    WHEN plan_change_enterprise = 'Upgrade from freemium' THEN 1
    WHEN plan_change_enterprise = 'Upgrade from other plans' THEN 1
    WHEN plan_change_enterprise = 'Upgrade from paying plans' THEN 1
    WHEN plan_change_enterprise = 'Upgrade from Escala' THEN 1
    WHEN plan_change_enterprise = 'Phoenix' THEN 1
    WHEN plan_change_enterprise = 'Evolución' THEN 0
    ELSE 0
  END AS plan_change_enterprise_numeric_indicator,

  CASE
    WHEN plan_level = 3 OR previous_plan_level = 3 THEN 1
    ELSE 0
  END AS is_escala_interest,

  CASE
    WHEN plan_level = 4 OR previous_plan_level = 4 THEN 1
    ELSE 0
  END AS is_enterprise_interest,

  -- 🔽 Colunas de auditoria
  current_timestamp AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int_plan_change_escala_stores') }} es
LEFT JOIN {{ ref('stg_active_merchants') }} am ON es.store_id = am.store_id
LEFT JOIN {{ ref('operations_grouping_plans') }} pc ON am.store_id_plan_country = pc.plan
LEFT JOIN {{ ref('moltres__mwp_store_info') }} msi ON es.store_id = msi.store_id
LEFT JOIN {{ ref('operations_grouping_plans') }} cc ON msi.plan = cc.plan
LEFT JOIN {{ ref('_int_plan_change_first_escala_payment') }} fpe ON es.store_id = fpe.store_id
LEFT JOIN {{ ref('_int_plan_change_first_enterprise_payment') }} fee ON es.store_id = fee.store_id
LEFT JOIN {{ ref('_int_plan_change_previous_plans') }} pp ON am.store_id = pp.store_id AND am.year = pp.year AND am.month = pp.month
LEFT JOIN {{ ref('operations_grouping_plans') }} prev_pc ON pp.prev_plan = prev_pc.plan
LEFT JOIN {{ ref('_int_plan_change_last_unpaid_contract') }} luc ON luc.store_id = es.store_id

ORDER BY am.store_id, am.year, am.month