-- Query plana que replica company_metrics_paid_orders para ejecutar en Databricks
-- Reemplaza todas las referencias dbt por nombres de tablas reales con hive_metastore
-- Esta query combina toda la lógica de staging, intermediate y data_product layers

WITH 
-- Replicando blocked_stores del intermediate model
blocked_stores AS (
    SELECT
        related_id
    FROM hive_metastore.moltres.mwp_tags as tg
    WHERE tg.type = 'store'
        AND (tg.tag = 'sre-block-store-429'
            OR tg.tag = 'sre-block-store-404')
),

-- Replicando payment_date del intermediate model  
payment_date AS (
    SELECT
        order_id,
        MAX(happened_at) as paid_at
    FROM hive_metastore.orders.mwp_orders_logging
    WHERE data_2 = 'paid'
    GROUP BY order_id
),

-- Replicando la tabla de orders base (staging orders)
base_orders AS (
    SELECT 
        id,
        created_at AS created_at,
        started_checkout AS started_checkout_at, 
        completed_contact AS completed_contact_at, 
        completed_at AS completed_at,
        cancelled_at AS cancelled_at, 
        store_id, 
        LOWER(contact_email) AS contact_email,
        currency,
        total, 
        total_in_usd, 
        storefront,
        status,
        device_type,
        payment_status,
        gateway,
        shipping_method,
        shipping_cost,
        shipping_option,
        shipping_pickup_type,
        shipping_province,
        gateway_integration_type,
        gateway_installments,
        gateway_method,
        app_id,
        CONCAT(CAST(DATE(completed_at) AS STRING),'-',CAST(store_id AS STRING)) order_date_store_id,
        CAST(date_format(completed_at, 'yyyyMMdd') AS INT) AS year_month_day_code,
        CASE  
            WHEN status != 'cancelled' 
                AND payment_status = 'paid' 
                AND completed_at is not null 
            THEN TRUE ELSE FALSE 
        END AS is_paid_order,
        CASE 
            WHEN device_type IN ('computer', 'phone') THEN device_type ELSE 'other' 
        END AS device
    FROM hive_metastore.orders.mwp_orders
    WHERE total_in_usd <= 10000 and total_in_usd >= 0
),

-- Replicando store_info (staging moltres)
store_info AS (
    SELECT 
        id as store_id,
        state, 
        country,
        currency,
        current_segment,
        first_payment,
        churned_at,
        created_at,
        plan, 
        verified, 
        register_url,
        main_user_id,
        partner_id, 
        partnership_type, 
        domain,
        CASE WHEN store_tags.store_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_store_blocked
    FROM hive_metastore.moltres.mwp_store_info AS msi
    LEFT JOIN (
        SELECT 
            related_id AS store_id
        FROM hive_metastore.moltres.mwp_tags
        WHERE type = 'store'
            AND tag IN ('sre-block-store-404', 'sre-block-store-429')
        GROUP BY related_id
    ) store_tags ON msi.id = store_tags.store_id
    WHERE state != 4
),

-- Replicando exchange rate para ARS
ars_exchange_rate AS (
    SELECT
        date_add(DATE(processed_at),1) processed_at,
        'ARS' isocode,
        'Pesos Argentinos' name,
        'AR' as country_currency_code,
        (1/selling_rate) indirect_exchange_rate,
        selling_rate direct_exchange_rate
    FROM hive_metastore.third_party.finance_exchange_rate_ars_to_usd
    WHERE processed_at >= DATE '2017-12-31'
),

-- Replicando exchange rate para otras monedas
orders_exchange_rates AS (
    SELECT 
        DATE(completed_at) as processed_at,
        currency as isocode,
        CASE
            WHEN currency = 'AED' THEN 'Dhirams'
            WHEN currency = 'AOA' THEN 'Kwanzas Angoleños'
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
    FROM base_orders
    WHERE currency not in ('ARS', 'ars')
    GROUP BY DATE(completed_at), currency
),

-- Combinando exchange rates
all_exchange_rates AS (
    SELECT * FROM ars_exchange_rate
    UNION ALL
    SELECT * FROM orders_exchange_rates
),

-- Intermediate model replicado: get_store_info
enriched_orders AS (
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
    FROM base_orders paid_orders
    INNER JOIN store_info on paid_orders.store_id = store_info.store_id
    LEFT JOIN hive_metastore.moltres.mwp_apps apps on CONCAT("app_",apps.id) = paid_orders.gateway
    LEFT JOIN hive_metastore.moltres.mwp_shipping_carriers shipping_carriers on CONCAT("api_",shipping_carriers.id) = paid_orders.shipping_method
    LEFT JOIN hive_metastore.moltres.mwp_apps apps_2 on apps_2.id = shipping_carriers.app_id
    LEFT JOIN payment_date on paid_orders.id = payment_date.order_id
    LEFT JOIN all_exchange_rates exchange_rate on DATE(paid_orders.completed_at) = DATE(exchange_rate.processed_at) 
        AND paid_orders.currency = exchange_rate.isocode
    LEFT JOIN all_exchange_rates exchange_rate_country on DATE(paid_orders.completed_at) = DATE(exchange_rate_country.processed_at) 
        AND store_info.country = exchange_rate_country.country_currency_code
    WHERE 
        paid_orders.store_id not in (SELECT related_id FROM blocked_stores)
        AND is_paid_order = TRUE AND storefront <> 'permalink'
        AND DATE(paid_orders.completed_at) < CURRENT_DATE()
),

-- Productos por orden (replicando company_metrics_products_per_order)
products_per_order AS (
    SELECT
        order_id,
        SUM(quantity) AS product_quantity
    FROM hive_metastore.orders.mwp_order_products products
    WHERE deleted_at IS NULL  -- Solo productos no eliminados
    GROUP BY order_id
)

-- Query principal que replica exactamente company_metrics_paid_orders
SELECT 
    orders.id,
    orders.store_id,
    orders.country,
    orders.completed_at,
    orders.gateway,
    orders.shipping_method,
    orders.storefront,
    orders.currency,
    CASE
        WHEN orders.country = 'AR' THEN 'ARS'
        WHEN orders.country = 'BR' THEN 'BRL'
        WHEN orders.country = 'MX' THEN 'MXN'
        WHEN orders.country = 'CO' THEN 'COP'
        WHEN orders.country = 'CL' THEN 'CLP'
        ELSE orders.currency
    END AS country_currency,
    orders.shipping_cost,
    orders.total_in_usd_billing as total_in_usd,
    orders.total_in_local_currency as total,
    orders.gateway_integration_type,
    orders.shipping_option,
    orders.shipping_pickup_type,
    orders.shipping_province,
    orders.gateway_installments,
    orders.gateway_method,
    orders.contact_email,
    orders.paid_at,
    orders.store_status,
    orders.payment,
    orders.shipping,
    orders.platform_type,
    products.product_quantity,
    orders.year_month_day_code,
    CASE
        WHEN orders.country = 'AR' and orders.currency = 'ARS' THEN FALSE
        WHEN orders.country = 'BR' and orders.currency = 'BRL' THEN FALSE
        WHEN orders.country = 'MX' and orders.currency = 'MXN' THEN FALSE
        WHEN orders.country = 'CO' and orders.currency = 'COP' THEN FALSE
        WHEN orders.country = 'CL' and orders.currency = 'CLP' THEN FALSE
        ELSE TRUE
    END AS is_foreign_currency,
    -- Campos de auditoría
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM enriched_orders orders
LEFT JOIN products_per_order products ON orders.id = products.order_id
WHERE orders.completed_at >= '2018-01-01'  -- Filtro base temporal

-- Opcional: agregar filtros adicionales
-- AND orders.completed_at >= '2024-01-01'  -- Para datos más recientes
-- AND orders.country = 'BR'  -- Para un país específico

ORDER BY orders.completed_at DESC;
