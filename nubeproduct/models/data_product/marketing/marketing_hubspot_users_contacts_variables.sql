{{
    config(
        materialized="incremental",
        unique_key="user_id",
        on_schema_change="sync_all_columns",
        incremental_strategy="merge",
        tags=["daily-6am"],
        partition_by=["year_month_day_code"],
    )
}}

with source_data as (
    select distinct
        p.email,
        p.user_id,
        p.is_main_user,
        coalesce(f.has_2fa, false) as has_2fa
    from {{ ref('_int_marketing_hubspot_users_contacts_profile') }} p
    left join {{ ref('_int_marketing_hubspot_users_contacts_2fa') }} f on f.user_id = p.user_id
)

select
    info.email,
    info.user_id,
    info.is_main_user,
    info.has_2fa,
    {% if is_incremental() %}
        coalesce(
            existing_data.sys_audit_created_on, current_timestamp
        ) as sys_audit_created_on,
        coalesce(
            existing_data.sys_audit_created_by, 'data-dev-dbt-products'
        ) as sys_audit_created_by,
    {% else %}
        current_timestamp as sys_audit_created_on,
        'data-dev-dbt-products' as sys_audit_created_by,
    {% endif %}
    current_timestamp as sys_audit_updated_on,
    cast(date_format(current_timestamp, 'yyyyMMdd') as int) as year_month_day_code,
    'data-dev-dbt-products' as sys_audit_updated_by
from source_data as info
{% if is_incremental() %}
    left join
        {{ this }} as existing_data on info.user_id = existing_data.user_id
        {% set monitored_cols = [
            "email",
            "is_main_user",
            "has_2fa",
        ] %}
    where
        existing_data.user_id is null
        {%- for col in monitored_cols %}
            or (info.{{ col }} is distinct from existing_data.{{ col }})
        {%- endfor %}
{% endif %}

