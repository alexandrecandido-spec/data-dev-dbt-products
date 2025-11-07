-- Extracts the raw delivery order data from Nuvem Envio systems, mapping relevant fields such as store, carrier, dimensions, and identifiers. 
-- It serves as the base for shipment-related transformations.
{{
    config(
        materialized='table',
        unique_key= 'id',
        on_schema_change='fail',
        tags=["logistics","daily-8am"]
    )
}}

SELECT
    year_month_code,
    id,
    created_at,
    DATE(dispatched_at) AS dispatched_at,
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