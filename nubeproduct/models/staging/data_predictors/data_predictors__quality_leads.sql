{{
    config(
        materialized='incremental',
        unique_key='store_id',
        partition_by = 'year_month_day_code',
        on_schema_change='fail',
        tags=["marketing","daily-9am"]
    )
}}

WITH source AS (
SELECT
    DISTINCT pp.store_id,
    pp.created_at,
    mv.model_id,
    pp.predicted_prob,
    CAST(date_format(pp.created_at, 'yyyyMMdd') AS INT) AS year_month_day_code
FROM  {{source('stg_data_predictors', 'marketing_new_payment_predictor')}} AS pp
LEFT JOIN {{source('stg_data_predictors', 'marketing_model_version_aux')}} AS mv 
        ON pp.model_id = mv.model_id
        AND pp.created_at BETWEEN mv.became_production - INTERVAL '72 hours' 
        AND COALESCE(mv.left_production, '2999-12-31') - INTERVAL '72 hours' 
WHERE mv.became_production IS NOT NULL
{% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND created_at >= (select coalesce(max(created_at),'1900-01-01') from {{ source('stg_data_predictors','marketing_new_payment_predictor') }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)


SELECT 
    source.store_id,
    source.created_at,
    source.model_id,
    source.predicted_prob,
    source.year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.store_id = e.store_id 