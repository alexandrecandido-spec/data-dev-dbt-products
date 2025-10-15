-- Filters delivery orders from staging:
--   - Only key carriers (Correios, Loggi, Mandae, Jadlog)
--   - Only data from January 2024 onwards

SELECT
    do.id,
    do.created_at,
    DATE(do.dispatched_at) AS postage_label_created_at,
    do.order_id,
    do.store_id,
    do.carrier_code,
    do.tracking_code,
    CASE
        WHEN do.carrier_code IN ('correios', 'jadlog', 'loggi', 'mandae') THEN 'BR'
        WHEN do.carrier_code IN ('correo-argentino', 'andreani') THEN 'AR'
        WHEN do.carrier_code IN ('envia') THEN 'MX'
        ELSE NULL
        END AS country
FROM {{ ref('nuvem_envio__delivery_order') }} do
INNER JOIN {{ ref('moltres__mwp_store_info') }} i 
        ON do.store_id = i.store_id
        AND i.country IN ('BR', 'AR', 'MX')
        AND i.state <> 4
WHERE year_month_code >= 202301
    AND do.carrier_code IN ('correios', 'jadlog', 'loggi', 'mandae', 'correo-argentino', 'andreani','envia')