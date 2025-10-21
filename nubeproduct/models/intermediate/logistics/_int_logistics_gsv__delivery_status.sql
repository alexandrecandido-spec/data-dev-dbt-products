-- Enriches shipment information with logistics status (created/posted) by combining data from accounting entries, invoices, and tracking events. 
-- It standardizes delivery statuses across systems.

WITH
tracking_history AS (
SELECT
    tracking_code,
    MIN(event_date) AS event_date
FROM {{source('int_logistics_tracking', 'tracking_history') }}
WHERE 1=1
    AND nuvem_envio_status IN ('dispatched', 'in-transit', 'out-for-delivery', 'delivered')
GROUP BY 1
)
SELECT
    fdo.id,
    COALESCE(p.posted_at, th.event_date) AS posted_at,
    CASE
      WHEN ae.billing_status = 'provisioned' 
        AND ae.type = 'deliveryOrder' THEN 'created'
      WHEN ae.billing_status IN ('billed', 'pre-billed') 
        AND ae.type = 'deliveryOrder' THEN 'posted'
      WHEN p.posted_at IS NOT NULL THEN 'posted'
      WHEN th.tracking_code IS NOT NULL THEN 'posted'
      WHEN fdo.postage_label_created_at IS NOT NULL THEN 'created'
      ELSE 'other_delivery_status'
    END AS delivery_status
FROM {{ ref('_int_logistics_gsv__filtered_delivery_order') }} fdo
    LEFT JOIN {{source('int_nuvem_envio_conciliation', 'accounting_entry') }} ae
        ON fdo.id = ae.delivery_order_id
    LEFT JOIN {{source('int_nuvem_envio_conciliation', 'pre_invoice') }} p 
        ON fdo.id = p.delivery_order_id
    LEFT JOIN tracking_history th
        ON fdo.tracking_code = th.tracking_code
