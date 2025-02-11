{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='fail',
        tags=["finance","daily-morning"]
    )
}}


WITH source AS (
    SELECT 
        TRY_CAST(id AS BIGINT) AS order_id, 
        TRY_CAST(created_at AS TIMESTAMP) AS created_at,
        TRY_CAST(started_checkout AS TIMESTAMP) AS started_checkout_at, 
        TRY_CAST(completed_contact AS TIMESTAMP) AS completed_contact_at, 
        TRY_CAST(completed_at AS TIMESTAMP) AS completed_at,
        TRY_CAST(cancelled_at AS TIMESTAMP) AS cancelled_at, 
        store_id, 
        LOWER(contact_email) AS contact_email, 
        total_in_usd, 
        storefront,
        status,
        device_type,
        payment_status,
        gateway,
        order_id as ejemplo

    FROM {{ source('orders', 'mwp_orders') }}
    WHERE total_in_usd <= 10000 and total_in_usd >= -10000
    
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('orders','mwp_orders') }} )

    {% endif %}
)

SELECT 
    *,
    CASE  
        WHEN status != 'cancelled' AND payment_status = 'paid' THEN TRUE ELSE FALSE 
    END AS is_paid_order,
    CASE 
        WHEN device_type IN ('computer', 'phone') THEN device_type ELSE 'other' 
    END AS device
FROM source