-- Handles paid orders that are not already linked to shipments in Brazil.
-- Enriches records with store information and shipping details.
-- Maintains shipment_id granularity for consistency with shipments datasets.

WITH
paid_orders_aux AS (
  SELECT
    fpo.order_id AS shipment_id,
    fpo.store_id,
    fpo.payment_status,
    fpo.store_id,
    CAST(fpo.completed_at AS DATE) AS completed_at,
    fpo.class AS shipment_type,
    fpo.total AS gmv,
    fpo.country
FROM {{ ref('_int_logistics_gsv__filtered_paid_orders') }} fpo
  LEFT JOIN {{ ref('_int_logistics_gsv__shipments') }} sh
    ON sh.shipment_id = fpo.order_id
  WHERE sh.shipment_id IS NULL

)


SELECT
  DISTINCT
    poa.shipment_id,
    poa.payment_status,
    poa.store_id,
    mi.domain,
    mi.current_segment_name AS current_segment,
    mi.vertical_name,
    mi.group_name AS plan,
    mi.created_at AS store_creation_date,
    mi.base_state_name AS store_state_name,
    CAST(poa.completed_at AS DATE) AS completed_at,
    NULL AS final_date,
    NULL AS postage_label_creation_date,
    poa.shipment_type,
    NULL AS gsv,
    poa.gmv,
    0   AS flg_gsv,
    1   AS flg_gmv,
    0   AS flg_shipment,
    COALESCE(ff.flg_multicd, 0) AS flg_multicd,
    CASE
      WHEN spi.carrier_name = 'Nuvem Envio' THEN 1
      ELSE 0
      END AS flg_ne_selected,
    CASE
      WHEN spi.carrier_name = 'Nuvem Envio' THEN 1
      ELSE COALESCE(ns.flg_ne_enabled,0)
      END AS flg_ne_enabled,
    COALESCE(spi.selected_shipping_partner, 'Custom') AS selected_shipping_partner,
    NULL AS delivery_shipping_partner,
    NULL AS carriers,
    NULL AS delivery_status,
    poa.country
FROM paid_orders_aux poa
  LEFT JOIN {{ ref('company_metrics_merchant_info') }} mi
    ON poa.store_id = mi.store_id
  LEFT JOIN {{ ref('_int_logistics_gsv__fullfilment_orders') }} ff
    ON poa.shipment_id = ff.order_id
  LEFT JOIN {{ ref('_int_logistics_gsv__shipping_info') }} spi
    ON poa.shipment_id = spi.order_id
  LEFT JOIN {{ ref('_int_logistics_gsv__stores_ne_enabled') }} ns
    ON poa.store_id = ns.store_id

  
