-- Filters delivery orders from staging:
--   - Only key carriers (Correios, Loggi, Mandae, Jadlog)
--   - Only data from January 2024 onwards

SELECT
    do.id AS delivery_order_id,
    DATE(do.created_at) AS postage_label_creation_date,
    do.order_id,
    do.store_id,
    do.carrier_code
FROM {{ ref('nuvem_envio__delivery_order') }} do
WHERE year_month_code >= 202401
    AND do.carrier_code IN ('correios', 'jadlog', 'loggi', 'mandae')