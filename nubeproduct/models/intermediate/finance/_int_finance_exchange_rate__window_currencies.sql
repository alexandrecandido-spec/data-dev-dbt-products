WITH ars_exchange_rate AS (
    SELECT
        date_add(DATE(processed_at),1) processed_at,
        'ARS' isocode,
        'Pesos Argentinos' name,
        'AR' as country_currency_code,
        (1/selling_rate) indirect_exchange_rate,
        selling_rate direct_exchange_rate
    FROM
        {{ source('int_third_party', 'finance_exchange_rate_ars_to_usd') }}
    WHERE
    processed_at >= DATE '2017-12-31'
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
    CASE
        WHEN currency = 'AED' THEN 'AE'
        WHEN currency = 'AOA' THEN 'AO'
        --WHEN currency = 'ARS' THEN 'Pesos Argentinos'
        WHEN currency = 'AUD' THEN 'AU'
        WHEN currency = 'BOB' THEN 'BO'
        WHEN currency = 'BRL' THEN 'BR'
        WHEN currency = 'CAD' THEN 'CA'
        WHEN currency = 'CLP' THEN 'CL'
        WHEN currency = 'CNY' THEN 'CN'
        WHEN currency = 'COP' THEN 'CO'
        WHEN currency = 'CRC' THEN 'CR'
        WHEN currency = 'EUR' THEN 'EU'
        WHEN currency = 'GBP' THEN 'GB'
        WHEN currency = 'GTQ' THEN 'GT'
        WHEN currency = 'ILS' THEN 'IL'
        WHEN currency = 'INR' THEN 'IN'
        WHEN currency = 'JPY' THEN 'JP'
        WHEN currency = 'MXN' THEN 'MX'
        WHEN currency = 'PEN' THEN 'PE'
        WHEN currency = 'PYG' THEN 'PY'
        WHEN currency = 'RUB' THEN 'RU'
        WHEN currency = 'SEK' THEN 'SE'
        WHEN currency = 'USD' THEN 'US'
        WHEN currency = 'UYU' THEN 'UY'
        WHEN currency = 'VEF' THEN 'VE'
        WHEN currency = 'VES' THEN ''
        WHEN currency = 'ZAR' THEN 'ZA'
    END AS country_currency_code,
    SUM(total_in_usd) / SUM(total) AS indirect_exchange_rate,
    SUM(total) / SUM(total_in_usd) AS direct_exchange_rate
FROM {{ ref('orders__mwp_orders') }}
WHERE currency not in ('ARS', 'ars')
GROUP BY DATE(completed_at), currency
)

SELECT * FROM ars_exchange_rate
UNION ALL
SELECT * FROM orders_exchange_rates