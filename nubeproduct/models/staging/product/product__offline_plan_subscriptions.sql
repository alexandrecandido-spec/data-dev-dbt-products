{{config(
    materialized = 'incremental',
    unique_key = 'subscription_id',
    on_schema_change = 'fail',
    tags = ['product', 'daily-10am']
)}}

-- gets merchants valid subscriptions
WITH subscriptions AS (
SELECT
    id AS subscription_id
    , store_id
    , plan_id
    , start_date
    , end_date
    , CAST(COALESCE(cpt_override, cpt, 0) AS DECIMAL(10,4)) AS cpt -- CPT Override is a manual adjustment applied for the merchant
FROM
    {{ source('stg_offline', 'plan_subscriptions')}}
WHERE
    active = TRUE -- only considers truly activated plans

    {% if is_incremental() %}
    AND sys_audit_updated_on >= (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{this}})
    {% endif %}
)

, existing_data AS (
    {{ get_existing_data(this, ['subscription_id', 'sys_audit_created_on', 'sys_audit_created_by'])}}
)

SELECT
    subscriptions.subscription_id
    , subscriptions.store_id
    , subscriptions.plan_id
    , subscriptions.start_date
    , subscriptions.end_date
    , subscriptions.cpt
    , COALESCE(existing_data.sys_audit_created_on, CURRENT_TIMESTAMP) AS sys_audit_created_on
    , COALESCE(existing_data.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    subscriptions
LEFT JOIN
    existing_data
    ON subscriptions.subscription_id = existing_data.subscription_id