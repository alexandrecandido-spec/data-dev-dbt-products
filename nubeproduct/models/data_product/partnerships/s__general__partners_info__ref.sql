{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='partner_id',
        on_schema_change='fail',
        tags=["partnerships", "daily-7am"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['partner_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
trial_info as (
    SELECT 
    SI.partner_id,
    MAX(CASE WHEN SI.partnership_type = 'store_development' THEN 1 ELSE 0 END) AS has_store_dev_trial,
    MAX(CASE WHEN SI.partnership_type = 'affiliate' THEN 1 ELSE 0 END) AS has_affiliates_trial 
    FROM {{ ref('_int_partners__agencies_affiliates_stores_store_info') }} AS SI
    GROUP BY SI.partner_id
),
source_data AS (
    SELECT 
    PI.*
    ,COALESCE(TI.has_store_dev_trial, 0) as has_store_dev_trial
    ,COALESCE(TI.has_affiliates_trial, 0) as has_affiliates_trial
    FROM {{ ref('_int_partnerships__partners_info') }} AS PI
    LEFT JOIN trial_info AS TI ON PI.partner_id = TI.partner_id
    WHERE
    {% if not is_incremental() %}
        PI.partner_created_at >= DATE '1900-01-01'
    {% endif %} 
    {% if is_incremental() %}
        PI.change_timestamp > ( SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }} )
    {% endif %}
)

SELECT 
SD.*
,COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data SD
LEFT JOIN existing_data E
    ON SD.partner_id = E.partner_id
    

