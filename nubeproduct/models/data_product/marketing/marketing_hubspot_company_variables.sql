{{ config(materialized="table", tags=["daily-6am"]) }}

with
    existing_data as (
        {{
            get_existing_data(
                this, ["store_id", "sys_audit_created_on", "sys_audit_created_by"]
            )
        }}
    ),
    dependency_audit_dates as (
        select
            merchant.store_id,
            greatest(
                merchant.sys_audit_updated_on,
                coalesce(segment.sys_audit_updated_on, merchant.sys_audit_updated_on),
                coalesce(vertical.sys_audit_updated_on, merchant.sys_audit_updated_on)
            ) as max_dependency_audit_date
        from {{ ref("dim_merchant_info") }} merchant
        left join
            {{ ref("dim_segment_type") }} segment
            on segment.segment_id = merchant.current_segment_id
        left join
            {{ ref("dim_vertical_type") }} vertical
            on vertical.vertical_id = merchant.vertical_id
    ),
    merchant_info as (
        select
            merchant.store_id,
            coalesce(segment.segment_name, '') as status_by_order_str,
            coalesce(vertical.vertical_name, '') as vertical_str,
            audit_dates.max_dependency_audit_date
        from {{ ref("dim_merchant_info") }} merchant
        left join
            {{ ref("dim_segment_type") }} segment
            on segment.segment_id = merchant.current_segment_id
        left join
            {{ ref("dim_vertical_type") }} vertical
            on vertical.vertical_id = merchant.vertical_id
        left join
            dependency_audit_dates audit_dates
            on audit_dates.store_id = merchant.store_id
    )

select
    info.store_id,
    info.status_by_order_str,
    info.vertical_str,
    coalesce(existing.sys_audit_created_on, current_timestamp) as sys_audit_created_on,
    coalesce(
        existing.sys_audit_created_by, 'data-dev-dbt-products'
    ) as sys_audit_created_by,
    info.max_dependency_audit_date as sys_audit_updated_on,
    'data-dev-dbt-products' as sys_audit_updated_by
from merchant_info info
left join existing_data existing on info.store_id = existing.store_id
