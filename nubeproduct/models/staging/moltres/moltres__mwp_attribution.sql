{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags=["marketing","daily-9am"]
    )
}}
WITH attribution AS (
    SELECT 
        CAST(id AS STRING) AS id,
        CAST(sys_audit_updated_on AS TIMESTAMP) AS sys_audit_updated_on,
        CAST(store_id AS STRING) AS store_id,
        CAST(source AS STRING) AS source,
        CAST(medium AS STRING) AS medium,
        CAST(term AS STRING) AS term,
        CAST(content AS STRING) AS content,
        CAST(campaign AS STRING) AS campaign,
        CAST(matchtype AS STRING) AS matchtype,
        CAST(placement AS STRING) AS placement,
        CAST(adposition AS STRING) AS adposition,
        CAST(device AS STRING) AS device,
        CAST(devicemodel AS STRING) AS devicemodel,
        CAST(http_referrer AS STRING) AS http_referrer,
        CAST(landing_page AS STRING) AS landing_page,
        CAST(date AS TIMESTAMP) AS date,
        CAST(sys_audit_created_on AS TIMESTAMP) AS sys_audit_created_on,
        CAST(sys_audit_created_by AS STRING) AS sys_audit_created_by,
        CAST(sys_audit_updated_by AS STRING) AS sys_audit_updated_by
    FROM {{ source('stg_moltres', 'mwp_attribution') }}
        {% if is_incremental() %}
        where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
        {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)
SELECT 
    att.* EXCEPT(sys_audit_created_on, sys_audit_created_by, sys_audit_updated_on, sys_audit_updated_by),
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM attribution AS att
LEFT JOIN existing_data AS e ON att.id = e.id