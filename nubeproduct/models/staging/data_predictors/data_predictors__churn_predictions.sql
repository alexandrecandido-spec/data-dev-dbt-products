{{
    config(
        materialized='incremental',
        incremental_strategy = 'merge',
        unique_key=['store_id', 'churn_prediction_period', 'execution_date'],
        on_schema_change='fail',
        tags=["marketing","monthly-2nd-10AM"]
    )
}}

--A Validar la tag de execution schedule 
--churn_model_data
WITH source AS (
    SELECT
    mcmp.store_id
    , mcmp.country as country
    , date(mcmp.mes_fim) as churn_prediction_period
    , mcmp.date_exec as execution_date
    , mcmp.life_stage as life_stage_at_prediction 
    , mcmp.seller_type as seller_type
    , mcmp.segmento_mensal as segment_at_prediction
    , mcmp.segmento_max as max_segment
    , mcmp.predicted_prob as churn_predicted_prob
    , mcmp.cutoff as churn_cutoff
    , mcmp.predicted as churn_prediction
    FROM {{source('stg_data_predictors', 'marketing_churn_model_predictions')}} AS mcmp
    WHERE
    {% if not is_incremental() %}
       date(mcmp.mes_fim) >= DATE '2025-01-01'
    {% endif %}
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    date(mcmp.mes_fim) > (select coalesce(max(churn_prediction_period), DATE '2025-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'churn_prediction_period', 'execution_date', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)


SELECT 
    source.store_id,
    source.churn_prediction_period,
    source.execution_date,
    source.country,
    source.life_stage_at_prediction,
    source.seller_type,
    source.segment_at_prediction,
    source.max_segment,
    source.churn_predicted_prob,
    source.churn_cutoff,
    source.churn_prediction,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.store_id = e.store_id 
                            AND source.churn_prediction_period = e.churn_prediction_period 
                            AND source.execution_date = e.execution_date