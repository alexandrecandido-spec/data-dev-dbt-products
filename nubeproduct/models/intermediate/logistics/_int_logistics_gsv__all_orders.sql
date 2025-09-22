-- Consolidates both paid and not-paid orders into a single unified dataset.
-- Acts as the base table for linking orders to shipments.

SELECT * FROM {{ ref('_int_logistics_gsv__filtered_paid_orders') }}
UNION ALL
SELECT * FROM {{ ref('_int_logistics_gsv__filtered_not_paid_orders') }}