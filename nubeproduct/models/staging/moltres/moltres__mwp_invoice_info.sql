
{{
    config(
        materialized='table',
        on_schema_change='fail',
        tags=["logistics","daily-8am"]
    ) 
}}

SELECT
    store_id,
    id_type,
    id_number,
    name AS business_name,
    type
FROM {{ source('stg_moltres', 'mwp_invoice_info') }}