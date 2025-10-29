{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['id'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

select
    id,
    store_id,
    domain,
    country,
    current_segment,
    state,
    plan,
    cast(location_id as varchar(10)) location_id,
    location_created_at,
    location_deleted_at,
    cast(location_destination_id as varchar(10)) location_destination_id,
    location_destination_created_at,
    location_destination_deleted_at,
    transfer_mode,
    status, 
    extra_info,
    created_at,
    products_to_transfer,
    products_transferred,
    variants_to_transfer,
    variants_transferred,
    quantity_to_transfer,
    tranferred_quantity_done,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__stock_transfers') }} sl
 {% if is_incremental() %}
    WHERE 
        sl.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} a )
    {% endif %}