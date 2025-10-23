WITH commissions AS
(
  SELECT 
    PL.id AS commission_id,
    partners_id AS partner_id,
    store_id,
    partner_ledger_entry_type_id,
    PLET.name AS partner_ledger_entry_type_name,
    IF(partner_ledger_entry_type_id IN(5,7),'Withdrawal','Deposit') AS transaction_type,
    CASE 
      WHEN partner_ledger_entry_type_id = 1 
      THEN 'affiliates'
      WHEN partner_ledger_entry_type_id = 6 
      THEN 'store_development'
      WHEN partner_ledger_entry_type_id IN(2,8) 
      THEN 'apps'
      WHEN partner_ledger_entry_type_id = 3 
      THEN 'initial_balance'
      WHEN partner_ledger_entry_type_id = 4 
      THEN 'partner_bonus'
      ELSE 'payout'
    END AS commission_type,
    DATE(paid_at) AS commission_paid_date,
    DATE(created_at) AS commission_created_date,
    target_currency AS partner_currency,
    original_currency AS store_currency,
    currency_exchange_rate,
    CASE 
      WHEN partner_ledger_entry_type_id IN(2,3,4,5,7,8) 
      THEN ABS(credit_value)
      ELSE partner_commission_value
    END AS commission_amount,
    status AS commission_status,
    partner_commission_percentage,
    plan_id,
    plan_value,
    DATE
    (
      GREATEST
        (
          PL.sys_audit_updated_on, 
          PLET.sys_audit_updated_on
        )
    ) AS partner_ledger_change_timestamp
  FROM {{ source('int_ecosystem', 'partner_ledger') }} AS PL
  LEFT JOIN {{ source('int_ecosystem', 'partner_ledger_entry_type') }} AS PLET
    ON PL.partner_ledger_entry_type_id = PLET.id
  WHERE DATE(PL.created_at) >= '2024-01-01'
)
SELECT * FROM commissions