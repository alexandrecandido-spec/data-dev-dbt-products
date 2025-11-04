{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id', 'report_date'],
        partition_by=['report_date'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

WITH 
-- Historical data from existing notebook table (only on first run)
{% if not is_incremental() %}
historical_data AS (
    SELECT
        CAST(report_date AS DATE) AS report_date,
        store_id,
        domain,
        active,
        state,
        current_timestamp AS sys_audit_created_on,
        'data-dev-dbt-products' AS sys_audit_created_by,
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM {{ source('dp_testing', 'daily_email_template_data') }}
    -- Exclude today's date to avoid overlap with new_data
    WHERE CAST(report_date AS DATE) < current_date()
),
{% endif %}

-- New incremental data from source
source_data AS (
    SELECT
        e.store_id,
        i.domain,
        e.active,
        i.state,
        current_date() AS report_date
    FROM {{ source('dp_moltres', 'mwp_email_templates_v2') }} e
    LEFT JOIN {{ ref('moltres__mwp_store_info') }} i 
        ON e.store_id = i.store_id
    WHERE e.type = 'orderreadyforpickup' 
        AND (e.active = 1 OR e.active IS NULL)
    
    {% if is_incremental() %}
        -- Only process new data since last run
        AND current_date() > (SELECT COALESCE(MAX(report_date), '1900-01-01') FROM {{ this }})
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'report_date', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

new_data AS (
    SELECT
        source_data.report_date,
        source_data.store_id,
        domain,
        active,
        state,
        COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
        COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
        current_timestamp AS sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM source_data
    LEFT JOIN existing_data e 
        ON source_data.store_id = e.store_id 
        AND source_data.report_date = e.report_date
)

-- Combine historical and new data on first run, otherwise just new data
{% if not is_incremental() %}
SELECT * FROM historical_data
UNION ALL
SELECT * FROM new_data
{% else %}
SELECT * FROM new_data
{% endif %}