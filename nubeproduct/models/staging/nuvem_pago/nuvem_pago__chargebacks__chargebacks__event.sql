{{
    config(
        materialized='incremental',
        unique_key='_id',
        partition_by='year_month_code',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}


WITH source AS (
    SELECT 
        createdAt_date,
        _id,
        amount,
        chargeback,
        createdAt,
        customer,
        events,
        failureReason,
        orderId,
        orderNumber,
        origin,
        paidAt,
        paymentMethod,
        remainingAmountToRefund,
        status,
        storeId,
        transactionId,
        updatedAt,
        cascadia_event_timestamp,
        source_event_timestamp,
        source_event_order,
        year_month_code
    FROM {{ source('stg_nuvem_pago', 'charges_dashboard') }}
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 hour' from {{ this }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    createdAt_date,
    source._id,
    amount,
    chargeback,
    createdAt,
    customer,
    events,
    failureReason,
    orderId,
    orderNumber,
    origin,
    paidAt,
    paymentMethod,
    remainingAmountToRefund,
    status,
    storeId,
    transactionId,
    updatedAt,
    cascadia_event_timestamp,
    source_event_timestamp,
    source_event_order,
    year_month_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source._id = e._id
