{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'append',
        unique_key = ['partner_id','snapshot_date'],
        on_schema_change = 'fail',
        tags = ['weekly-monday-10am']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['partner_id', 'snapshot_date', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
agencies_performance_summary AS 
(
    SELECT
        snapshot_date,
        partner_id,
        partner_code,
        partner_created_at,
        partner_country_code,
        all_time_stores,
        all_time_new_payments,
        all_time_new_sellers,
        first_trial_at,
        first_payment_at,
        first_seller_at,
        freemium_stores,
        active_trials,
        active_paying_stores,
        freemium_stores_with_gmv_last_90_days,
        churned_stores,
        -- Current month metrics
        trials_current_month,
        new_payments_current_month,
        new_sellers_current_month,
        gmv_usd_current_month,
        gmv_local_currency_current_month,
        -- Previous month metrics
        trials_previous_month,
        new_payments_previous_month,
        new_sellers_previous_month,
        gmv_usd_previous_month,
        gmv_local_currency_previous_month,
        -- Last quarter metrics
        trials_last_quarter,
        new_payments_last_quarter,
        new_sellers_last_quarter,
        gmv_usd_last_quarter,
        gmv_local_currency_last_quarter,
        -- Last year metrics
        trials_last_year,
        new_payments_last_year,
        new_sellers_last_year,
        gmv_usd_last_year,
        gmv_local_currency_last_year,
        -- Rolling periods
        trials_last_30d,
        new_payments_last_30d,
        new_sellers_last_30d,
        gmv_usd_last_30d,
        gmv_local_currency_last_30d,
        -- Last 90 days metrics
        trials_last_90d,
        new_payments_last_90d,
        new_sellers_last_90d,
        gmv_usd_last_90d,
        gmv_local_currency_last_90d,
        -- Last 180 days metrics
        trials_last_180d,
        new_payments_last_180d,
        new_sellers_last_180d,
        gmv_usd_last_180d,
        gmv_local_currency_last_180d,
        -- Last 365 days metrics
        trials_last_365d,
        new_payments_last_365d,
        new_sellers_last_365d,
        gmv_usd_last_365d,
        gmv_local_currency_last_365d
    FROM {{ ref('_int_partners__agencies_performance_summary_metrics_construction') }}
)
SELECT 
    agencies_performance_summary.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM agencies_performance_summary
LEFT JOIN existing_data e
    ON agencies_performance_summary.partner_id = e.partner_id
    AND agencies_performance_summary.snapshot_date = e.snapshot_date
    {% if is_incremental() %}
WHERE    
      agencies_performance_summary.snapshot_date > 
        (
            SELECT COALESCE(MAX(snapshot_date), DATE '1900-01-01')
            FROM {{ this }}
        )
    {% endif %}




