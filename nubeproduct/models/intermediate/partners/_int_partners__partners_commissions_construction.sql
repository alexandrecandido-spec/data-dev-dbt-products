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
    DATE(paid_at) AS commission_date,
    target_currency AS partner_currency,
    original_currency AS store_currency,
    currency_exchange_rate,
    CASE 
      WHEN partner_ledger_entry_type_id = 2 
      THEN credit_value
      WHEN partner_ledger_entry_type_id = 5 
      THEN IF(credit_value < 0, credit_value * -1, credit_value)
      ELSE partner_commission_value
    END AS commission_amount,
    status AS commission_status,
    partner_commission_percentage,
    plan_id,
    plan_value
  FROM {{ source('int_ecosystem', 'partner_ledger') }}
)
SELECT * FROM commissions