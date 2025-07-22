{{
    config(
        materialized='table',
        unique_key= 'billing_cycle_id',
        on_schema_change='fail',
        tags=["logistics","daily-8am"]
    )
}}

SELECT
    billing_cycle_id,
    external_store_id,
    carrier_code,
    cost_charge_value
FROM {{ source('stg_nuvem_envio_billing', 'cycle_by_carrier') }}
WHERE carrier_code IN ('correios', 'jadlog', 'mandae', 'loggi')