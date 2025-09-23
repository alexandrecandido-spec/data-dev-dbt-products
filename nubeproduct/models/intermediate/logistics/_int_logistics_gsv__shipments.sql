-- Normalizes data to ensure one row per unique shipment_id.
-- Main steps:
--   1. status_priorizado → prioritizes shipment status ("posted" > "created" > others)
--   2. carrier_agg → determines the main carrier or "Multi-carrier"
--   3. info_complementar → aggregates store info, GMV, GSV and flags
-- Result: clean and deduplicated dataset of shipments ready for analytics.

WITH
status_priorizado AS (
    SELECT
        shipment_id,
        CASE 
            WHEN MAX(CASE WHEN delivery_status = 'posted' THEN 1 ELSE 0 END) = 1 THEN 'posted'
            WHEN MAX(CASE WHEN delivery_status = 'created' THEN 1 ELSE 0 END) = 1 THEN 'created'
            ELSE FIRST(delivery_status, true)
        END AS delivery_status
    FROM {{ ref('_int_logistics_gsv__all_shipments') }}
    GROUP BY shipment_id
),

carrier_agg AS (
    SELECT
        shipment_id,
        CASE 
            WHEN SIZE(collect_set(delivery_shipping_partner)) > 1 THEN 'Multi-carrier'
            ELSE MAX(delivery_shipping_partner)
        END AS delivery_carrier,
        array_join(collect_set(delivery_shipping_partner), ';') AS carriers
    FROM {{ ref('_int_logistics_gsv__all_shipments') }}
    GROUP BY shipment_id
),

info_complementar AS (
    SELECT
        shipment_id,
        ANY_VALUE(payment_status) AS payment_status,
        ANY_VALUE(store_id) AS store_id,
        ANY_VALUE(domain) AS domain,
        ANY_VALUE(current_segment) AS current_segment,
        ANY_VALUE(vertical_name) AS vertical_name,
        ANY_VALUE(plan) AS plan,
        ANY_VALUE(store_creation_date) AS store_creation_date,
        ANY_VALUE(store_state_name) AS store_state_name,
        ANY_VALUE(completed_at) AS completed_at,
        ANY_VALUE(final_date) AS final_date,
        ANY_VALUE(postage_label_creation_date) AS postage_label_creation_date,
        ANY_VALUE(shipment_type) AS shipment_type,
        ANY_VALUE(gsv) AS gsv,
        ANY_VALUE(gmv) AS gmv,
        ANY_VALUE(flg_gsv) AS flg_gsv,
        ANY_VALUE(flg_gmv) AS flg_gmv,
        ANY_VALUE(flg_shipment) AS flg_shipment,
        ANY_VALUE(flg_multicd) AS flg_multicd,
        ANY_VALUE(flg_ne_selected) AS flg_ne_selected,
        ANY_VALUE(flg_ne_enabled) AS flg_ne_enabled,
        ANY_VALUE(selected_shipping_partner) AS selected_shipping_partner,
        ANY_VALUE(country) AS country
    FROM {{ ref('_int_logistics_gsv__all_shipments') }}
    GROUP BY shipment_id
)

SELECT
    s.shipment_id,
    i.payment_status,
    i.store_id,
    i.domain,
    i.current_segment,
    i.vertical_name,
    i.plan,
    i.store_creation_date,
    i.store_state_name,
    i.completed_at,
    i.final_date,
    i.postage_label_creation_date,
    CASE 
      WHEN s.delivery_status = 'created' AND i.shipment_type  = 'Paid delivered order' THEN 'Postage label created' 
      WHEN s.delivery_status = 'created' AND i.shipment_type  = 'Cancelled delivered order' THEN 'Postage label created' 
      ELSE i.shipment_type 
      END  AS shipment_type,
    CASE WHEN s.delivery_status != 'posted' THEN NULL ELSE i.gsv END AS gsv,
    i.gmv,
    CASE WHEN s.delivery_status != 'posted' THEN 0 ELSE i.flg_gsv END AS flg_gsv,
    i.flg_gmv,
    i.flg_shipment,
    i.flg_multicd,
    i.flg_ne_selected,
    i.flg_ne_enabled,
    i.selected_shipping_partner,
    c.delivery_carrier AS delivery_shipping_partner,
    c.carriers,
    s.delivery_status,
    i.country

FROM status_priorizado s
  LEFT JOIN carrier_agg c 
    ON s.shipment_id = c.shipment_id
  LEFT JOIN info_complementar i 
    ON s.shipment_id = i.shipment_id
WHERE delivery_status IN ('created', 'posted')
