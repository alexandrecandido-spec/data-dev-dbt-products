{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='fail'
    )
}}


WITH source AS (
    SELECT 
        id,
        external_cart_id,
        created_at
    FROM {{ source('wallet', 'started_checkout_express') }}
    WHERE created_at >= DATE_ADD(DAY, -31, CURRENT_DATE)

    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('wallet','started_checkout_express') }} )

    {% endif %}
)

SELECT 
    TRY_CAST(external_cart_id AS BIGINT) as order_id,
    created_at
FROM source


