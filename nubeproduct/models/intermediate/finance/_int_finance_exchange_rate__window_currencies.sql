WITH ars_exchange_rate AS (
    SELECT
        DATE(processed_at) processed_at,
        'ARS' isocode,
        'Pesos Argentinos' name,
        (1/selling_rate) indirect_exchange_rate,
        selling_rate direct_exchange_rate
    FROM
        {{ source('int_third_party', 'finance_exchange_rate_ars_to_usd') }}
    WHERE
    processed_at >= DATE '2018-01-01'
),
orders_exchange_rates AS (
SELECT 
    DATE(completed_at) as processed_at,
    currency as isocode,
    CASE
        WHEN currency = 'AED' THEN 'Dhirams'
        WHEN currency = 'AOA' THEN 'Kwanzas Angoleños'
        --WHEN currency = 'ARS' THEN 'Pesos Argentinos'
        WHEN currency = 'AUD' THEN 'Dólares Australianos'
        WHEN currency = 'BOB' THEN 'Bolivianos'
        WHEN currency = 'BRL' THEN 'Reales'
        WHEN currency = 'CAD' THEN 'Dólares Canadienses'
        WHEN currency = 'CLP' THEN 'Pesos Chilenos'
        WHEN currency = 'CNY' THEN 'Yuans'
        WHEN currency = 'COP' THEN 'Pesos Colombianos'
        WHEN currency = 'CRC' THEN 'Colón Costarricense'
        WHEN currency = 'EUR' THEN 'Euros'
        WHEN currency = 'GBP' THEN 'Libras'
        WHEN currency = 'GTQ' THEN 'Quetzales'
        WHEN currency = 'ILS' THEN 'Nuevo Shéquel Israelí'
        WHEN currency = 'INR' THEN 'Rupias'
        WHEN currency = 'JPY' THEN 'Yens'
        WHEN currency = 'MXN' THEN 'Pesos Mexicanos'
        WHEN currency = 'PEN' THEN 'Soles'
        WHEN currency = 'PYG' THEN 'Guaraní Paraguayo'
        WHEN currency = 'RUB' THEN 'Rublos'
        WHEN currency = 'SEK' THEN 'Corona Sueca'
        WHEN currency = 'USD' THEN 'Dólares'
        WHEN currency = 'UYU' THEN 'Pesos Uruguayos'
        WHEN currency = 'VEF' THEN 'Bolívares Fuertes Venezolanos'
        WHEN currency = 'VES' THEN 'Bolívares Soberanos'
        WHEN currency = 'ZAR' THEN 'Rand Sudafricano'
    END AS name,
    SUM(total_in_usd) / SUM(total) AS indirect_exchange_rate,
    SUM(total) / SUM(total_in_usd) AS direct_exchange_rate
FROM {{ ref('orders__mwp_orders') }}
WHERE currency <> 'ARS'
GROUP BY DATE(completed_at), currency
)

SELECT * FROM ars_exchange_rate
UNION ALL
SELECT * FROM orders_exchange_rates