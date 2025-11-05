{{ config(
    materialized        = 'incremental',
    incremental_strategy= 'merge',
    unique_key          = 'hash_partner_key',
    on_schema_change    = 'fail',
    tags                = ['daily-9am','marketing']
) }}

WITH existing_data AS (
    {{ get_existing_data(
        this, [
            'hash_partner_key',
            'trials',
            'new_payments',
            'payments',
            'new_sellers',
            'current_churn_stores',
            'qls',
            'current_churn_stores_created_at',
            'new_sellers_first_payment',
            'first_churn_30d',
            'first_churn_60d',
            'first_churn_90d',
            'first_churn_post_90d',
            'total_gmv',
            'total_orders',
            'sys_audit_created_on',
            'sys_audit_created_by'
        ])
    }}
),

base AS (
    SELECT *
    FROM {{ ref('_int__affiliates_performance_metrics') }}
    WHERE partner_id IS NOT NULL
),

partners AS (
    SELECT
        partner_id,
        affiliate_tier,
        partner_code,
        affiliate_classification,
        partner_utm_campaign,
        partner_utm_source,
        partner_utm_medium,
        partner_utm_content,
        mkt_exclusion,
        flag_partner_exception
    FROM {{ ref('s__general__partners_info__ref') }}
),

joined AS (
    SELECT
        md5(CONCAT(b.partner_id, b.country_code, b.date, b.new_seller, b.is_store_blocked)) AS hash_partner_key,

        b.partner_id,
        b.country_code,
        b.is_store_blocked,
        b.new_seller,
        b.date,

        -- Partner Data
        p.partner_code,
        p.affiliate_tier,
        p.affiliate_classification,
        p.partner_utm_campaign,
        p.partner_utm_source,
        p.partner_utm_medium,
        p.partner_utm_content,
        p.mkt_exclusion,
        p.flag_partner_exception,

        -- Metrics
        b.trials,
        b.new_payments,
        b.payments,
        b.new_sellers,
        b.current_churn_stores,
        b.qls,
        b.current_churn_stores_created_at,
        b.new_sellers_first_payment,
        b.first_churn_30d,
        b.first_churn_60d,
        b.first_churn_90d,
        b.first_churn_post_90d,
        b.total_gmv,
        b.total_orders

    FROM base b
    LEFT JOIN partners p ON b.partner_id = p.partner_id 
)

SELECT
    j.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-marketing') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-marketing' AS sys_audit_updated_by
FROM joined j
LEFT JOIN existing_data e ON j.hash_partner_key = e.hash_partner_key
WHERE
    {% if is_incremental() %}
        e.hash_partner_key IS NULL
        OR j.trials IS DISTINCT FROM e.trials
        OR j.new_payments IS DISTINCT FROM e.new_payments
        OR j.payments IS DISTINCT FROM e.payments
        OR j.new_sellers IS DISTINCT FROM e.new_sellers
        OR j.current_churn_stores IS DISTINCT FROM e.current_churn_stores
        OR j.qls IS DISTINCT FROM e.qls
        OR j.current_churn_stores_created_at IS DISTINCT FROM e.current_churn_stores_created_at
        OR j.new_sellers_first_payment IS DISTINCT FROM e.new_sellers_first_payment
        OR j.first_churn_30d IS DISTINCT FROM e.first_churn_30d
        OR j.first_churn_60d IS DISTINCT FROM e.first_churn_60d
        OR j.first_churn_90d IS DISTINCT FROM e.first_churn_90d
        OR j.first_churn_post_90d IS DISTINCT FROM e.first_churn_post_90d
        OR j.total_gmv IS DISTINCT FROM e.total_gmv
        OR j.total_orders IS DISTINCT FROM e.total_orders
    {% else %}
        TRUE
    {% endif %}
