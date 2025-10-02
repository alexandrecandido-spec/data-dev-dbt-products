-- Consolidates both paid and not-paid orders into a single unified dataset.
-- Acts as the base table for linking orders to shipments.


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