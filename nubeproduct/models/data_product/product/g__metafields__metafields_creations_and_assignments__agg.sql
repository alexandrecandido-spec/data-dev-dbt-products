{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        partition_by=['year_month_code'],
        unique_key=['metafield_id'],
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
    metafield_id,
    metafield_name,
    metafield_data_type,
    metafield_created_at,
    CAST(date_format(metafield_created_at, 'yyyyMM') AS INT) AS year_month_code,
    metafield_deleted_at,
    mf_is_active,
    domain,
    mf_is_assigned,
    first_date_mf_was_assigned,
    last_date_mf_was_assigned,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int__product__metafields_and_assignments') }}  j
    {% if is_incremental() %}
    WHERE 
     j.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}