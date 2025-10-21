{{
    config(
        materialized='incremental',
        unique_key=['run_date', 'plan_group', 'state', 'current_segment', 'country'],
        incremental_strategy='append',
        on_schema_change='fail',
        tags=['weekly-monday-9am']
    )
}}

WITH run_period AS (
    SELECT 
        {% if is_incremental() %}
        COALESCE(
           (SELECT MAX(sys_audit_updated_on)::DATE FROM {{ this }}),
           current_date - INTERVAL '7 days'
        ) AS period_start_date,
        {% else %}
        current_date - INTERVAL '7 days' AS period_start_date,
        {% endif %}
        current_date AS period_end_date
),

adjusted_intermediate AS (
    SELECT 
        current_date AS run_date,
        rp.period_start_date AS period_start_date,
        rp.period_end_date AS period_end_date,
        plan_group,
        state,
        current_segment,
        country,
        enabled_stores_count,
        period_installed_count,
        period_started_trial_count,
        period_has_paid_count,
        period_churned_count,
        cumulative_installed_count,
        cumulative_started_trial_count,
        cumulative_has_paid_count,
        cumulative_churned_count,
        total_stores_count
    FROM {{ ref('_int_product__nuvemchat_weekly_funnel') }} int_data
    CROSS JOIN run_period rp
)

SELECT 
    run_date,
    period_start_date,
    period_end_date,
    plan_group,
    state,
    current_segment,
    country,
    enabled_stores_count,
    period_installed_count,
    period_started_trial_count,
    period_has_paid_count,
    period_churned_count,
    cumulative_installed_count,
    cumulative_started_trial_count,
    cumulative_has_paid_count,
    cumulative_churned_count,
    total_stores_count,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM adjusted_intermediate

{% if is_incremental() %}
WHERE
    run_date > (
        SELECT max(run_date) 
        FROM {{ this }} 
        )
{% endif %}