{{
  config(
    materialized='incremental',
    unique_key=['pay_order_id', 'charge_id'],
    on_schema_change='fail',
    tags=['finance', 'daily-7am']
  )
}}

WITH source_data AS (
    SELECT
        CONCAT(payorderid, '_', chargeid) AS pay_order_charge_id, -- Composite key since id column doesn't exist
        payorderid AS pay_order_id,
        chargeid AS charge_id,
        sys_audit_created_on AS source_sys_audit_created_on,
        sys_audit_created_by AS source_sys_audit_created_by,
        -- updatedat column not available in this source table
        CAST(date_format(sys_audit_created_on, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM
        {{ source('stg_billing', 'pay_order_charge') }}

    -- No updatedat column available for incremental logic
),

existing_data AS (
    {{ get_existing_data(this, ['pay_order_charge_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    s.pay_order_charge_id,
    s.pay_order_id,
    s.charge_id,
    s.year_month_day_code,
    -- s.updated_at, -- Column not available
    COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    source_data s
LEFT JOIN
    existing_data e ON s.pay_order_charge_id = e.pay_order_charge_id