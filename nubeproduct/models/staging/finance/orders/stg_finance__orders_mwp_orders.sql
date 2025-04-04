{{
    config(
        materialized='incremental',
        unique_key='id',
        partition_by='year_month_day_code',
        on_schema_change='fail',
        tags=["daily-morning"]
    )
}}


WITH source AS (
    SELECT 
        id,
        created_at AS created_at,
        started_checkout AS started_checkout_at, 
        completed_contact AS completed_contact_at, 
        completed_at AS completed_at,
        cancelled_at AS cancelled_at, 
        store_id, 
        LOWER(contact_email) AS contact_email,
        currency,
        total, 
        total_in_usd, 
        storefront,
        status,
        device_type,
        payment_status,
        gateway,
        CONCAT(CAST(DATE(completed_at) AS STRING),'-',CAST(store_id AS STRING)) order_date_store_id,
        CAST(to_date(completed_at, 'yyyyMMdd') AS STRING) AS year_month_day_code

    FROM {{ source('orders', 'mwp_orders') }}
    WHERE total_in_usd <= 10000 and total_in_usd >= -10000
    
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('orders','mwp_orders') }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.id, 
    created_at,
    started_checkout_at, 
    completed_contact_at, 
    completed_at,
    cancelled_at, 
    store_id, 
    LOWER(contact_email) AS contact_email, 
    currency,
    total,
    total_in_usd, 
    storefront,
    status,
    device_type,
    payment_status,
    gateway,
    order_date_store_id,
    year_month_day_code,
    CASE  
        WHEN status != 'cancelled' AND payment_status = 'paid' THEN TRUE ELSE FALSE 
    END AS is_paid_order,
    CASE 
        WHEN device_type IN ('computer', 'phone') THEN device_type ELSE 'other' 
    END AS device,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.id = e.id