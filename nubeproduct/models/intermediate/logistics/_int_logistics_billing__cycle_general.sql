SELECT
    bcf.store_id,
    bcf.external_pay_order_id,
    pt.paid_order_id,
    bcf.billing_cycle_id,
    si.domain,
    bcf.cycle_status,
    bcf.payment_expiration_date,
    bcf.created_at,
    pt.payment_history_paid_at,
    ii.id_type,
    ii.id_number,
    ii.business_name,
    bcf.invoice_emission_date,
    bcf.invoice_number,
    bcf.billing_cycle_end_date,
    r.receipt_number,
    bcf.original_payment_value,
    bcf.payment_value,
    bcf.adjustment_value,
    bcf.invoice_value,
    bcf.receipt_value,
    bcf.penalty_value,
    bcf.payment_method_fee_value,
    bcf.correios_cost_value,
    bcf.jadlog_cost_value,
    bcf.loggi_cost_value,
    bcf.mandae_cost_value,
    ROW_NUMBER() OVER (PARTITION BY bcf.store_id, bcf.billing_cycle_id ORDER BY bcf.billing_cycle_end_date DESC) AS rnk
FROM {{ ref('_int_logistics_billing__cycle_filtered') }} bcf
INNER JOIN {{ ref('moltres__mwp_store_info') }} si
    ON si.store_id = TRY_CAST(bcf.store_id AS BIGINT)
INNER JOIN {{ ref('_int_logistics_billing__invoice_info_ranked') }} ii
    ON ii.store_id = TRY_CAST(bcf.store_id AS BIGINT)
LEFT JOIN {{ ref('_int_logistics_billing__payment_transaction') }} pt
    ON pt.paid_order_id = bcf.external_pay_order_id
LEFT JOIN {{ ref('billing__receipt') }} r
    ON r.id = bcf.external_receipt_id
