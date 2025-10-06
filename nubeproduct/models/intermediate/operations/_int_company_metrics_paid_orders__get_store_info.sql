WITH
blocked_stores AS (
    SELECT
        related_id
    FROM {{ source('int_moltres', 'mwp_tags') }} as tg
    WHERE tg.type = 'store'
        AND (tg.tag = 'sre-block-store-429'
            OR tg.tag = 'sre-block-store-404')
),
payment_date AS (
    SELECT
        order_id,
        MAX(happened_at) as paid_at
    FROM
        orders.mwp_orders_logging
    WHERE
        data_2 = 'paid'
    GROUP BY order_id)

SELECT 
    paid_orders.*,
    paid_orders.total / exchange_rate.direct_exchange_rate AS total_in_usd_billing,
    CASE 
        WHEN exchange_rate_country.country_currency_code = store_info.country THEN
            (paid_orders.total / exchange_rate.direct_exchange_rate) * exchange_rate_country.direct_exchange_rate 
        ELSE
            paid_orders.total_in_usd / exchange_rate.indirect_exchange_rate
    END AS total_in_local_currency,
    CASE
        WHEN storefront in ('mobile', 'store', 'form', 'social', 'pos') or (storefront = 'api' and paid_orders.app_id=12217) THEN 'on'
        ELSE 'off'
    END AS platform_type,
    store_info.country,
    CASE
        WHEN store_info.churned_at is null
            AND store_info.first_payment is not null then 'Paying'
        WHEN store_info.first_payment is not null then 'Churned'
        ELSE 'Non activated / Trial'
    END AS store_status,
    CASE 
        WHEN apps.handle is not null then apps.handle
        WHEN paid_orders.gateway = 'testmode' then 'custom'
        ELSE paid_orders.gateway
    END AS payment,
    CASE 
        WHEN apps_2.handle is not null then apps_2.handle
        WHEN paid_orders.shipping_method = 'table' then 'custom'
        ELSE paid_orders.shipping_method
    END AS shipping,
    payment_date.paid_at
FROM {{ ref('orders__mwp_orders') }} paid_orders
INNER JOIN {{ ref('moltres__mwp_store_info') }} store_info on paid_orders.store_id = store_info.store_id
LEFT JOIN {{ source('int_moltres', 'mwp_apps') }} apps on CONCAT("app_",apps.id) = paid_orders.gateway
LEFT JOIN {{ source('int_moltres', 'mwp_shipping_carriers') }} shipping_carriers on CONCAT("api_",shipping_carriers.id) = paid_orders.shipping_method
LEFT JOIN {{ source('int_moltres', 'mwp_apps') }} apps_2 on apps_2.id = shipping_carriers.app_id
LEFT JOIN payment_date on paid_orders.id = payment_date.order_id
LEFT JOIN {{ ref('finance_exchange_rate') }} exchange_rate on DATE(paid_orders.completed_at) = DATE(exchange_rate.processed_at) 
    AND paid_orders.currency = exchange_rate.isocode
LEFT JOIN {{ ref('finance_exchange_rate') }} exchange_rate_country on DATE(paid_orders.completed_at) = DATE(exchange_rate_country.processed_at) 
    AND store_info.country = exchange_rate_country.country_currency_code
WHERE 
    paid_orders.store_id not in (SELECT related_id FROM blocked_stores)
    AND is_paid_order = TRUE AND storefront <> 'permalink'
    AND DATE(paid_orders.completed_at) < CURRENT_DATE()
    AND paid_orders.total_in_usd <= 10000 AND paid_orders.total_in_usd >= 0
