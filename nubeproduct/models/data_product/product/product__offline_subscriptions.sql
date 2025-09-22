{{ config( 
    materialized = 'incremental',
    unique_key = 'subscription_id',
    on_schema_change = 'fail',
    tags = ['daily-10am']
) }}

-- gets plan data with final date treated
WITH base AS (
SELECT
    subscription_id
    , store_id
    , plan_name
    , plan_type
    , start_date
    , effective_end_date
    , next_start_date
    , cpt
    , bill_cycle
    , subscription_updated_on
    , store_updated_on
FROM
    {{ ref('_int_product__offline_subscription_with_end_date') }}
)

, existing_data AS (
    {{ get_existing_data(this, ['subscription_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    base.subscription_id
    , base.store_id
    , base.plan_name
    , base.plan_type
    , base.start_date
    , base.effective_end_date
    , base.next_start_date
    , base.cpt
    , base.bill_cycle
    , COALESCE(existing_data.sys_audit_created_on, CURRENT_TIMESTAMP) AS sys_audit_created_on
    , COALESCE(existing_data.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    base
LEFT JOIN
    existing_data
    ON base.subscription_id = existing_data.subscription_id
    
{% if is_incremental() %}
WHERE
    GREATEST(
        COALESCE(base.store_updated_on, DATE '1900-01-01'),
        COALESCE(base.subscription_updated_on, DATE '1900-01-01')
    ) >= (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }})
{% endif %}
