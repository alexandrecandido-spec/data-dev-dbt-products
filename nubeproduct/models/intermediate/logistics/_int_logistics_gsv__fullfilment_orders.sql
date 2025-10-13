-- Maps fulfillment orders linked to store orders. 
-- It flags multi-CD (multi-fulfillment) cases and contributes to shipment-level aggregation.

SELECT
      of.fulfillment_order_id
    , of.order_id
    , ao.store_id
    , ao.total
    , ao.completed_at
    , ao.class
    , ao.flg_gmv
    , ao.payment_status
    , ao.country
    , CASE 
        WHEN COUNT(of.order_id) OVER (PARTITION BY of.order_id) > 1 THEN 1 
        ELSE 0 
        END AS flg_multicd
FROM {{source('int_orders', 'mwp_orders_fulfillments') }} of
    INNER JOIN {{ ref('_int_logistics_gsv__all_orders') }} ao
      ON ao.order_id = of.order_id
WHERE of.year_month_code >= 202301