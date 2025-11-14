{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='partner_id',
        on_schema_change='fail',
        tags=["partnerships", "daily-10am"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['partner_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
status AS
(
    SELECT
        partner_id,
        partner_created_date,
        partner_level,
        partner_age_classification,
        partner_origin,
        partner_business_unit,
        active_paying_stores_flg,
        new_payments_lm3_flg,
        first_store_trial_date,
        first_store_payment_date,
        first_store_seller_date,
        last_store_trial_date,
        last_store_payment_date,
        last_store_seller_date,
        agencies_info_change_timestamp
    FROM {{ ref('_int_partnerships__agencies_info_construction') }}
)
SELECT 
    S.* EXCEPT(S.agencies_info_change_timestamp),
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM status AS S
LEFT JOIN existing_data AS e
    ON S.partner_id = e.partner_id
    {% if is_incremental() %}
WHERE    
      S.agencies_info_change_timestamp > 
        (
            SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
            FROM {{ this }}
        )
    {% endif %}