{{
    config(
        materialized='table',
        unique_key= 'id',
        on_schema_change='fail',
        tags=["logistics","daily-8am"]
    )
}}

SELECT
    id, 
    number AS receipt_number
FROM {{ source('stg_billing', 'receipt') }}