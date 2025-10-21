WITH commissions AS
(
  SELECT 
    id AS commission_id,
    partners_id AS partner_id,
    store_id,
    partner_ledger_entry_type_id,
    IF(partner_ledger_entry_type_id = 5,'Withdrawal','Deposit') AS transaction_type,
    CASE 
      WHEN partner_ledger_entry_type_id = 1 
      THEN 'affiliates'
      WHEN partner_ledger_entry_type_id = 6 
      THEN 'store_development'
      WHEN partner_ledger_entry_type_id = 2 
      THEN 'apps'
      ELSE 'Withdrawal'
    END AS commission_type,
    DATE(paid_at) AS commission_paid_date,
    DATE(created_at) AS commission_created_date,
    target_currency AS partner_currency,
    original_currency AS store_currency,
    currency_exchange_rate,
    CASE 
      WHEN partner_ledger_entry_type_id IN(2,5) 
      THEN ABS(credit_value)
      ELSE partner_commission_value
    END AS commission_amount,
    status AS commission_status,
    partner_commission_percentage,
    plan_id,
    plan_value,
    sys_audit_updated_on
  FROM {{ source('int_ecosystem', 'partner_ledger') }}
  WHERE DATE(created_at) >= '2024-01-01'
  AND partner_ledger_entry_type_id IN(1,2,5,6)
)
SELECT * FROM commissions