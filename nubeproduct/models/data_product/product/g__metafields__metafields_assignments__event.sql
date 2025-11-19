{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        partition_by=['year_month_code'],
        unique_key=['store_id','uuid','assignment_id'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

SELECT
    store_id,
    store_domain,
    state,
    country,
    current_segment,
    plan_name,
    created_by_app,
    avg_gmv_usd_last_3m,
    name_mf,
    uuid,
    metafield_data_type,
    mf_is_active,
    mf_is_assigned,
    metafield_created_at,
    CAST(date_format(metafield_created_at, 'yyyyMM') AS INT) AS year_month_code,
    domain,
    COALESCE(assignment_id, 0) AS assignment_id,
    assignment_date,
    owner_id,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int__product__metafield_assignments_events') }}  j
    {% if is_incremental() %}
    WHERE 
     j.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}