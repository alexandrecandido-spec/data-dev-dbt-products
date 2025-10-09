{{
    config(
        materialized="table",
        tags=["daily-4_30am"],
        partition_by=["year_month_day_code"],
    )
}}

with
    source_data as (
        select
            user_id,
            email,
            coalesce(
                nullif(trim(name), ''),
                'User-' || cast(user_id as string)
            ) as name,
            store_id,
            phone,
            has_store,
            user_is_partner,
            partner_id
        from {{ ref("_int_support_users_raw") }}
    )

select
    info.user_id,
    info.email,
    info.name,
    info.store_id,
    info.phone,
    info.has_store,
    info.user_is_partner,
    info.partner_id,
    current_timestamp as sys_audit_created_on,
    'data-dev-dbt-products' as sys_audit_created_by,
    current_timestamp as sys_audit_updated_on,
    cast(date_format(current_timestamp, 'yyyyMMdd') as int) as year_month_day_code,
    'data-dev-dbt-products' as sys_audit_updated_by
from source_data as info
