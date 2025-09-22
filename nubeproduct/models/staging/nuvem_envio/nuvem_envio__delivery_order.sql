-- Staging model that exposes delivery order data from Nuvem Envio.
-- Performs only basic selections and type casts to standardize columns.
SELECT
    year_month_code,
    id,
    created_at,
    external_sale_order_id AS order_id,
    CAST(external_store_id AS INT) AS store_id,
    carrier_code,
    delivery_option_code,
    tracking_code,
    weight,
    width,
    height,
    depth
FROM {{source('stg_nuvem_envio_conciliation', 'delivery_order') }}