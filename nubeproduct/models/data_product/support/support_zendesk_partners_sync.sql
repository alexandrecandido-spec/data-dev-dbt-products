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
    partner_tags as (
        select related_id as partner_id, string_agg(tag, ',') as partner_tags
        from {{ source("int_ecosystem", "tags") }}
        where type = 'partner' and tag in ('platinum', 'gold', 'silver')
        group by related_id
    ),
    source_data as (
        select
            mp.id as partner_id,
            mp.email,
            false as has_store,
            true as user_is_partner,
            pt.partner_tags
        from {{ source("int_ecosystem", "mwp_partners") }} as mp
        left join partner_tags pt on mp.id = pt.partner_id
        where 1 = 1 and mp.email is not null
    )

select
    info.partner_id,
    info.email,
    info.has_store,
    info.user_is_partner,
    info.partner_tags,
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
    cast(date_format(sys_audit_updated_on, 'yyyyMMdd') as int) as year_month_day_code,
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
        ] %}
    where
        existing_data.partner_id is null
        {%- for col in monitored_cols %}
            or (info.{{ col }} is distinct from existing_data.{{ col }})
        {%- endfor %}
{% endif %}
