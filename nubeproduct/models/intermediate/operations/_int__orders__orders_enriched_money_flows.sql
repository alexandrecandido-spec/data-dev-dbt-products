WITH
blocked_store__info AS (
  SELECT
    bl.store_id
    , bl.is_store_blocked
    , bl.blocked_at
    , bl.sys_audit_updated_on
  FROM {{ ref('s__lifecycle__store_status__ref') }} bl
  WHERE bl.blocked_reason is not null
),

payment_date AS (
    SELECT
        order_id,
        currency,
        MIN(happened_at) as paid_at,
        MAX(happened_at) as last_payment_at,
        sum(amount) as total_amount,
        sum(amount_usd) as total_amount_usd,
        max(sys_audit_updated_on) as sys_audit_updated_on
    FROM
        {{ ref('orders__order_money_flows__event') }}
    WHERE happened_at >= '2025-11-01' --Dívida técnica order_money_flow começa com a lógica de data de pagamento a partir de novembro de 2025. Time ferá rollout historico
    GROUP BY order_id,currency)

, payment_date_legacy AS (
    SELECT
        order_id,
        min(happened_at) as paid_at
    FROM
        {{ source('int_orders', 'mwp_orders_logging') }} 
    WHERE
        data_2 = 'paid'
    GROUP BY order_id)

, session_info AS (
    SELECT
        cart_id,
        source_name,
        source_group,
        google_subchannel,
        traffic_type,
        is_end_user,
        visitor_country
    FROM
        {{ ref('s__traffic__cart_session__link') }}
)

, order_products_quantity AS (
    SELECT
        order_id,
        SUM(
            quantity
        ) AS product_quantity,
        max(sys_audit_updated_on) as sys_audit_updated_on
    FROM {{ ref('orders__mwp_order_products') }} products
    GROUP BY order_id
)

SELECT 
    carts_orders.id,
    carts_orders.order_id,
    carts_orders.created_at,
    carts_orders.started_checkout_at,
    carts_orders.completed_contact_at,
    carts_orders.completed_at,
    carts_orders.cancelled_at,
    carts_orders.cancel_reason,
    carts_orders.store_id,
    carts_orders.contact_email,
    carts_orders.contact_name,
    carts_orders.currency,
    carts_orders.total,
    carts_orders.storefront,
    carts_orders.status,
    carts_orders.device_type,
    carts_orders.payment_status,
    carts_orders.gateway,
    carts_orders.internal_extra,
    carts_orders.shipping_method,
    carts_orders.shipping_cost,
    carts_orders.shipping_option,
    carts_orders.shipping_pickup_type,
    carts_orders.shipping_province,
    carts_orders.gateway_integration_type,
    carts_orders.gateway_installments,
    carts_orders.gateway_method,
    carts_orders.order_date_store_id,
    carts_orders.app_id,
    carts_orders.discount,
    carts_orders.discount_gateway,
    carts_orders.promotional_discount_id,
    carts_orders.shipping_cost_owner,
    carts_orders.fulfillment_status,
    carts_orders.device,
    carts_orders.order_traits,
    case when store_info.state = 4 then true else false end as is_test_store,
    CASE
        WHEN 
            carts_orders.payment_status in ('paid', 'partially_paid', 'partially_refunded') 
            AND coalesce(blocked_store__info.is_store_blocked, FALSE) = FALSE --store not declared fraud
            AND carts_orders.total_in_usd between 0 and 10000 --prevent fraud orders
            AND store_info.state <> 4 --store not test
            AND (
            carts_orders.status <> 'cancelled'
            OR 
            carts_orders.cancelled_at > date_add(last_day(COALESCE(payment_date.paid_at, carts_orders.completed_at)), 4)
        )
        THEN TRUE ELSE FALSE 
    END AS flg_gmv,
    coalesce(payment_date.total_amount, carts_orders.total) / exchange_rate.direct_exchange_rate AS total_in_usd,
    CASE 
        WHEN exchange_rate_country.country_currency_code = store_info.country THEN
            (coalesce(payment_date.total_amount, carts_orders.total) / exchange_rate.direct_exchange_rate) * exchange_rate_country.direct_exchange_rate 
        ELSE
            coalesce(payment_date.total_amount_usd, carts_orders.total_in_usd) / exchange_rate.indirect_exchange_rate
    END AS total_in_local_currency,
    CASE
        WHEN carts_orders.storefront = 'api' and carts_orders.app_id <> 12217 THEN 'off'
        ELSE 'on'
    END AS platform_type,
    store_info.country,
    CASE 
        WHEN apps.handle is not null then apps.handle
        WHEN carts_orders.gateway = 'testmode' then 'custom'
        ELSE carts_orders.gateway
    END AS payment_handler,
    apps.category as payment_handler_category,
    CASE 
        WHEN apps_2.handle is not null then apps_2.handle
        WHEN carts_orders.shipping_method = 'table' then 'custom'
        ELSE carts_orders.shipping_method
    END AS shipping_handler,
    apps_2.category as shipping_handler_category,
    coalesce(payment_date.paid_at, payment_date_legacy.paid_at) as paid_at,
    date(date_trunc('month', coalesce(payment_date.paid_at,carts_orders.completed_at))) as reporting_month,
    CAST(date_format(coalesce(coalesce(date(payment_date.paid_at), date(carts_orders.completed_at)),date(carts_orders.created_at)), 'yyyyMMdd') AS INT) as year_month_day_code,
    last_payment_at,
    coalesce(blocked_store__info.is_store_blocked, FALSE) as possible_fraud_order,
    session_info.source_name,
    session_info.source_group,
    session_info.google_subchannel,
    session_info.traffic_type,
    session_info.is_end_user,
    session_info.visitor_country,
    coalesce(all_shipments.flg_gsv, 0) as flg_gsv,
    coalesce(all_shipments.flg_multicd, 0) as flg_multicd,
    coalesce(all_shipments.flg_ne_selected, 0) as flg_ne_selected,
    coalesce(all_shipments.flg_ne_enabled, 0) as flg_ne_enabled,
    all_shipments.selected_shipping_partner,
    order_products_quantity.product_quantity,
    GREATEST(
        date(COALESCE(carts_orders.sys_audit_updated_on, '1900-01-01')),
        date(COALESCE(payment_date.sys_audit_updated_on, '1900-01-01')),
        date(COALESCE(all_shipments.posted_at, '1900-01-01')),
        date(COALESCE(blocked_store__info.sys_audit_updated_on, '1900-01-01')),
        date(COALESCE(order_products_quantity.sys_audit_updated_on, '1900-01-01'))
    ) as sys_audit_updated_on
FROM {{ ref('orders__mwp_orders') }} carts_orders
INNER JOIN {{ ref('moltres__mwp_store_info') }} store_info on carts_orders.store_id = store_info.store_id
LEFT JOIN order_products_quantity on carts_orders.id = order_products_quantity.order_id
LEFT JOIN {{ source('int_moltres', 'mwp_apps') }} apps on CONCAT("app_",apps.id) = carts_orders.gateway
LEFT JOIN {{ source('int_moltres', 'mwp_shipping_carriers') }} shipping_carriers on CONCAT("api_",shipping_carriers.id) = carts_orders.shipping_method
LEFT JOIN {{ source('int_moltres', 'mwp_apps') }} apps_2 on apps_2.id = shipping_carriers.app_id
LEFT JOIN payment_date on carts_orders.id = payment_date.order_id
LEFT JOIN {{ ref('finance_exchange_rate') }} exchange_rate on DATE(carts_orders.completed_at) = DATE(exchange_rate.processed_at) 
    AND carts_orders.currency = exchange_rate.isocode
LEFT JOIN {{ ref('finance_exchange_rate') }} exchange_rate_country on DATE(carts_orders.completed_at) = DATE(exchange_rate_country.processed_at) 
    AND store_info.country = exchange_rate_country.country_currency_code
LEFT JOIN {{ ref('_int_logistics_gsv__shipments')}} all_shipments on carts_orders.id = all_shipments.order_id
LEFT JOIN blocked_store__info on carts_orders.store_id = blocked_store__info.store_id
LEFT JOIN session_info on carts_orders.id = session_info.cart_id
LEFT JOIN payment_date_legacy on carts_orders.id = payment_date_legacy.order_id