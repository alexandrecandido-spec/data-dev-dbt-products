-- Builds a unified view of shipments in Brazil.
-- Joins fulfillment orders, paid orders, not-paid orders and delivery orders.
-- Business logic applied:
--   - Defines shipment type (Paid, Cancelled, Fulfillment, etc.)
--   - Calculates GSV and GMV flags
--   - Identifies if Nuvem Envio was selected or enabled
--   - Standardizes carriers (Correios, Loggi, Mandae, Jadlog)
-- Result: base table for all logistics shipment analysis.

 SELECT
    COALESCE(ff.order_id, ao.order_id, fdo.delivery_order_id)         AS shipment_id,
    COALESCE(ff.payment_status, ao.payment_status, 'detached')       AS payment_status,
    fdo.store_id,
    mi.domain,
    mi.current_segment_name                                           AS current_segment,
    mi.vertical_name,
    mi.group_name                                                     AS plan,
    mi.created_at                                                     AS store_creation_date,
    mi.base_state_name                                                AS store_state_name,
    CAST(COALESCE(ff.completed_at, ao.completed_at) AS DATE)          AS completed_at,
    CAST(COALESCE(p.posted_at, 
      COALESCE(ff.completed_at, ao.completed_at)) AS DATE)            AS final_date,
    postage_label_creation_date,

    CASE
      WHEN ff.class IS NOT NULL THEN 'Fulfillment order'
      WHEN ao.class = 'Cancelled order' THEN 'Cancelled delivered order'
      WHEN ao.class = 'Paid order' THEN 'Paid delivered order'
      ELSE 'Detached'
      END                                                             AS shipment_type,

    COALESCE(ff.total, ao.total)                                      AS gsv,
    COALESCE(CASE 
              WHEN ff.flg_gmv = 1 THEN ff.total 
              ELSE NULL 
              END, fpo.total)                                         AS gmv,
   
    CASE
      WHEN ff.class IS NOT NULL THEN 1
      WHEN ao.class = 'Cancelled order' THEN 1
      WHEN ao.class = 'Paid order' THEN 1
      ELSE 0
      END                                                             AS flg_gsv,

    CASE
      WHEN ff.flg_gmv IS NOT NULL THEN ff.flg_gmv
      WHEN ao.class = 'Paid order' THEN 1
      ELSE 0
      END                                                             AS flg_gmv,

    1                                                                 AS flg_shipment,

    COALESCE(ff.flg_multicd, 0)                                       AS flg_multicd,

    CASE
      WHEN spi.carrier_name = 'Nuvem Envio' THEN 1
      ELSE 0
      END                                                             AS flg_ne_selected,

    CASE
      WHEN spi.carrier_name = 'Nuvem Envio' THEN 1
      ELSE COALESCE(ns.flg_ne_enabled,0)
      END                                                              AS flg_ne_enabled,

    COALESCE(spi.selected_shipping_partner
      , ao.selected_shipping_partner, 'Custom')                        AS selected_shipping_partner,

    CASE
      WHEN fdo.carrier_code = 'correios' THEN 'Correios'
      WHEN fdo.carrier_code = 'loggi' THEN 'Loggi'
      WHEN fdo.carrier_code = 'mandae' THEN 'Mandae'
      WHEN fdo.carrier_code = 'jadlog' THEN 'Jadlog'
      ELSE NULL
    END                                                                 AS delivery_shipping_partner,


    CASE
      WHEN billing_status = 'provisioned' 
        AND type = 'deliveryOrder' THEN 'created'
      WHEN billing_status IN ('billed', 'pre-billed') 
        AND type = 'deliveryOrder' THEN 'posted'
      WHEN p.posted_at IS NOT NULL THEN 'posted'
      ELSE 'other_delivery_status'
    END                                                                 AS delivery_status,

  'BR'                                                                  AS country

FROM {{ ref('_int_logistics_gsv__filtered_delivery_order') }} fdo
    LEFT JOIN {{source('int_nuvem_envio_conciliation', 'accounting_entry') }} ae
      ON fdo.delivery_order_id = ae.delivery_order_id
    LEFT JOIN {{source('int_nuvem_envio_conciliation', 'pre_invoice') }} p 
      ON fdo.delivery_order_id = p.delivery_order_id
    LEFT JOIN {{ ref('_int_logistics_gsv__fullfilment_orders') }} ff
      ON fdo.order_id = ff.fulfillment_order_id
    LEFT JOIN {{ ref('_int_logistics_gsv__all_orders') }} ao
      ON fdo.order_id = ao.order_id
    LEFT JOIN {{ ref('company_metrics_merchant_info') }} mi
      ON fdo.store_id = mi.store_id
    LEFT JOIN {{ ref('_int_logistics_gsv__shipping_info') }} spi
      ON fdo.order_id = spi.order_id
    LEFT JOIN {{ ref('_int_logistics_gsv__stores_ne_enabled') }} ns
      ON fdo.store_id = ns.store_id
    LEFT JOIN {{ ref('_int_logistics_gsv__filtered_paid_orders') }} fpo
      ON fdo.order_id = fpo.order_id