{{ config(
    materialized='incremental',
    unique_key=['user_pseudo_id'],
    incremental_strategy='merge',
    partition_by= 'first_visit_date',
    on_schema_change='fail',
    tags=['marketing','daily-8am']
) }}
WITH existing_data AS (
    {{ get_existing_data(this, ['user_pseudo_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

select 
    source.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from {{ ref('_int_marketing_first_visit') }} source
LEFT JOIN existing_data e
    ON source.user_pseudo_id = e.user_pseudo_id
{% if is_incremental() %}
    WHERE source.first_visit_date >= (SELECT date_sub(MAX(sys_audit_updated_on), 5) FROM {{ this }})
{% endif %}