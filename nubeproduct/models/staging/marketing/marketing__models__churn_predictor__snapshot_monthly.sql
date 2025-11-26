{{
    config(
        materialized='incremental',
        incremental_strategy = 'merge',
        unique_key=['store_id', 'snapshot_month_end'],
        partition_by=['snapshot_month_end'],
        cluster_by=['store_id'],
        on_schema_change='fail',
        tags=["marketing","monthly-2nd-10AM"] 
    )
}}

/*
Staging: Churn Predictions Snapshot Monthly
Description: Snapshot of the churn predictions for each store and month.
Source: hive_metastore.data_predictors.marketing_potential_churn_predictions

Owner: marketing
Domain: models
POC: ianca.leite@nuvemshop.com.br


✅ INCREMENTAL Materialization:
   - Reprocesses the latest month and loads any newer months.
   - MERGE strategy with unique_key=['store_id', 'snapshot_month_end']


⚠️ TECHNICAL DEBT:
   This model replaces the data_predictors__churn_predictions model, which should be deprecated.
*/


--churn_model_data
WITH source AS (
    SELECT
    mcmp.store_id
    , mcmp.country
    , mcmp.month_end as snapshot_month_end
    , mcmp.timestamp as prediction_timestamp
    , mcmp.life_stage 
    , mcmp.month_segment
    , mcmp.max_segment
    , mcmp.seller_type
    , mcmp.profile
    , mcmp.probability
    , mcmp.threshold
    , mcmp.prediction
    , mcmp.model_id
    , CAST(date_format(mcmp.timestamp, 'yyyyMM') AS BIGINT) AS prediction_year_month_code
    , ROW_NUMBER() OVER (PARTITION BY mcmp.store_id, mcmp.month_end ORDER BY mcmp.timestamp DESC) AS rn
    FROM {{source('stg_data_predictors', 'marketing_potential_churn_predictions')}} AS mcmp
    WHERE
    {% if not is_incremental() %}
       date(mcmp.month_end) >= DATE '2025-01-01'
    {% endif %}
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose snapshot_month_end were included in the last run of this model -- max(snapshot_month_end))
    -- (If snapshot_month_end is NULL or the table is truncated, the condition will always be true and load all records)
    date(mcmp.month_end) >= (select coalesce(max(snapshot_month_end), DATE '2025-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'snapshot_month_end', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)


SELECT 
    source.store_id
    , source.country
    , source.snapshot_month_end
    , source.prediction_timestamp
    , source.life_stage
    , source.month_segment
    , source.max_segment
    , source.seller_type
    , source.profile
    , source.probability
    , source.threshold
    , source.prediction
    , source.model_id
    , source.prediction_year_month_code
    , COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
    , COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    , current_timestamp AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.store_id = e.store_id 
                            AND source.snapshot_month_end = e.snapshot_month_end 
WHERE source.rn = 1