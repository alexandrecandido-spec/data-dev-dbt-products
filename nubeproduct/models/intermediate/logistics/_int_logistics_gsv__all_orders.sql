-- Combines both paid and non-paid orders into a unified table that represents the complete order universe for GSV processing.


SELECT
    store_id,
    order_id,
    completed_at,
    payment_status,
    class,
    flg_gsv,
    flg_detached,
    flg_shipment,
    flg_gmv,
    gsv,
    total,
    country,
    shipping_method,
    selected_shipping_partner
FROM {{ ref('_int_logistics_gsv__filtered_paid_orders') }}

UNION ALL

SELECT
    store_id,
    order_id,
    completed_at,
    payment_status,
    class,
    flg_gsv,
    flg_detached,
    flg_shipment,
    flg_gmv,
    gsv,
    total,
    country,
    shipping_method,
    selected_shipping_partner
FROM {{ ref('_int_logistics_gsv__filtered_not_paid_orders') }}