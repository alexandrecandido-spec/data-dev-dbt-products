{{
    config(
        materialized='incremental', 
        unique_key=['order_id'],
        incremental_strategy='merge',
        on_schema_change='fail',
        partition_by=['year_month_day_code'],
        tags=["daily-9am-9pm"],
        cluster_by = ['store_id'],
        post_hook = [
            "OPTIMIZE {{ this }} ZORDER BY (order_id, paid_at)"
        ]
    )
}}


    SELECT
        order_id,
        currency,
        year_month_day_code,
        paid_at,
        last_payment_at,
        total_amount,
        total_amount_usd,
        sys_audit_updated_on
    FROM {{ ref('_int__orders__money_flows_agregation') }}