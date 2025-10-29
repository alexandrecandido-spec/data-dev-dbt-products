{{
    config(
        materialized="incremental",
        unique_key="user_id",
        on_schema_change="sync_all_columns",
        incremental_strategy="merge",
        tags=["daily-4_30am"],
        partition_by=["year_month_day_code"],
    )
}}

with
    source_data as (
        select
            user_id,
            email,
            name,
            phone,
            has_store,
            user_is_partner,
            partner_id,
            organization_id
        from {{ ref("_int_cx__zendesk_users_info") }}
    )

select
    info.user_id,
    info.email,
    info.name,
    info.phone,
    info.has_store,
    info.user_is_partner,
    info.partner_id,
    info.organization_id,
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
            "name",
            "phone",
            "has_store",
            "user_is_partner",
            "partner_id",
            "organization_id",
        ] %}
    where
        existing_data.user_id is null
        {%- for col in monitored_cols %}
            or (info.{{ col }} is distinct from existing_data.{{ col }})
        {%- endfor %}
{% endif %}
