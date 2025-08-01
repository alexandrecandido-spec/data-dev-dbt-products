SELECT
    bc.billing_cycle_id,
    bc.external_store_id AS store_id,
    bc.original_payment_value,
    bc.payment_value,
    bc.receipt_value,
    bc.penalty_value,
    bc.adjustment_value,
    bc.cycle_status,
    bc.payment_expiration_date,
    bc.created_at,
    bc.payment_method_fee_value,
    bc.invoice_emission_date,
    bc.invoice_number,
    bc.billing_cycle_end_date,
    bc.payment_status_updated_date,
    bc.invoice_value,
    bc.external_pay_order_id,
    bc.external_receipt_id,
    cc.correios_cost_value,
    cc.jadlog_cost_value,
    cc.mandae_cost_value,
    cc.loggi_cost_value
FROM {{ ref('nuvem_envio__billing_cycle') }} bc
LEFT JOIN {{ ref('_int_logistics_billing__cost_by_carrier') }} cc 
    ON bc.billing_cycle_id = cc.billing_cycle_id
    AND bc.external_store_id = cc.external_store_id
WHERE bc.currency = 'BRL'
  AND bc.year_month_code > CAST(DATE_FORMAT(DATE_SUB(CURRENT_DATE(), 365), 'yyyyMM') AS INT)
  AND bc.payment_value > 0