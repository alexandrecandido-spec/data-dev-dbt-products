{{ config(
    materialized='incremental',
    unique_key=['unique_session', 'user_pseudo_id', 'event_timestamp'],
    incremental_strategy='merge',
    on_schema_change='fail',
    tags=['marketing','daily-8am']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['unique_session', 'user_pseudo_id', 'event_timestamp', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

select
    source.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from {{ ref('_int_marketing_tp_info') }} source
LEFT JOIN existing_data e
    ON source.unique_session = e.unique_session
    AND source.user_pseudo_id = e.user_pseudo_id
    AND source.event_timestamp = e.event_timestamp
{% if is_incremental() %}
    WHERE source.trial_date >= (SELECT date_sub(MAX(sys_audit_updated_on), 5) FROM {{ this }})
    or source.payment_date >= (SELECT date_sub(MAX(sys_audit_updated_on), 5) FROM {{ this }})
{% endif %}