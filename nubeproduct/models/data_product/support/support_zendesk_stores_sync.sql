{{
    config(
        materialized="incremental",
        unique_key="external_id",
        incremental_strategy="merge",
        tags=["daily-4_30am"],
    )
}}

with
    source_data as (
        select
            segment.segment_name as status_by_orders,
            'https://stats.tiendanube.com/store/profile?store_id='
            || active_stores.store_id as url_stats,
            coalesce(
                nullif(trim(merchant.domain), ''),
                'Organization-' || active_stores.store_id
            ) as name,
            cast(active_stores.store_id as string) as external_id
        from {{ ref("hubspot_active_stores") }} active_stores
        left join
            {{ ref("dim_merchant_info") }} merchant
            on active_stores.store_id = merchant.store_id
        left join
            {{ ref("dim_segment_type") }} segment
            on segment.segment_id = merchant.current_segment_id
    )

select
    info.external_id,
    info.status_by_orders,
    info.url_stats,
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
    'data-dev-dbt-products' as sys_audit_updated_by
from source_data as info
{% if is_incremental() %}
    left join
        {{ this }} as existing_data on info.external_id = existing_data.external_id
        {% set monitored_cols = ["status_by_orders", "url_stats", "name"] %}
    where
        existing_data.external_id is null
        {%- for col in monitored_cols %}
            or (info.{{ col }} is distinct from existing_data.{{ col }})
        {%- endfor %}
{% endif %}
