{{
    config(
        materialized="incremental",
        unique_key="partner_id",
        on_schema_change="sync_all_columns",
        incremental_strategy="merge",
        tags=["daily-4_30am"],
        partition_by=["year_month_day_code"],
    )
}}

with
    source_data as (
        select
            p.partner_id,
            p.email,
            p.has_store,
            p.user_is_partner,
            t.partner_tags,
            n.name
        from {{ ref("_int_support_partners_profile") }} p
        left join
            {{ ref("_int_support_partners_tags") }} t on t.partner_id = p.partner_id
        left join
            {{ ref("_int_support_partners_name") }} n on n.partner_id = p.partner_id
    )

select
    info.partner_id,
    info.email,
    info.has_store,
    info.user_is_partner,
    info.partner_tags,
    info.name,
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
        {{ this }} as existing_data on info.partner_id = existing_data.partner_id
        {% set monitored_cols = [
            "email",
            "has_store",
            "user_is_partner",
            "partner_tags",
            "name",
        ] %}
    where
        existing_data.partner_id is null
        {%- for col in monitored_cols %}
            or (info.{{ col }} is distinct from existing_data.{{ col }})
        {%- endfor %}
{% endif %}
