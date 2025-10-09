{{
    config(
        materialized="incremental",
        unique_key="external_id",
        on_schema_change="sync_all_columns",
        incremental_strategy="merge",
        tags=["daily-4_30am"],
        partition_by=["year_month_day_code"],
    )
}}

with
    source_data as (
        select
            mp.status_by_orders,
            act.url_stats,
            mp.name,
            mp.age_range,
            mp.range_since_first_payment,
            mp.created_at_org,
            mp.country,
            mp.url_admin,
            tags.tags_routing,
            act.gmv,
            act.np_trx_last_30,
            act.np_kyc_rejected,
            act.np_clearsale_risk,
            act.np_document,
            aux.confirmed_account,
            aux.external_id,
            aux.ftp,
            mp.plan,
            aux.layout,
            aux.paid_until_at,
            aux.has_associated_partner,
            aux.has_instagram,
            store_status.status
        from {{ ref("hubspot_active_stores") }} active_stores
        left join
            {{ ref("_int_support_stores_merchant_profile") }} mp
            on mp.store_id = active_stores.store_id
        left join
            {{ ref("_int_support_stores_activity_and_np") }} act
            on act.store_id = active_stores.store_id
        left join
            {{ ref("_int_support_stores_aux_fields") }} aux
            on aux.store_id = active_stores.store_id
        left join
            {{ ref("_int_support_stores_tags_routing") }} tags
            on tags.store_id = active_stores.store_id
        left join
            {{ ref("_int_support_stores_status") }} store_status
            on store_status.store_id = active_stores.store_id
        left join
            {{ ref("marketing_merchant_info_refined") }} mir
            on mir.store_id = active_stores.store_id

    )

select
    info.external_id,
    info.status_by_orders,
    info.url_stats,
    info.name,
    info.age_range,
    info.range_since_first_payment,
    info.created_at_org,
    info.country,
    info.url_admin,
    info.tags_routing,
    info.gmv,
    info.np_trx_last_30,
    info.np_kyc_rejected,
    info.np_clearsale_risk,
    info.np_document,
    info.confirmed_account,
    info.ftp,
    info.plan,
    info.layout,
    info.paid_until_at,
    info.has_associated_partner,
    info.has_instagram,
    info.status,
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
        {{ this }} as existing_data on info.external_id = existing_data.external_id
        {% set monitored_cols = [
            "status_by_orders",
            "url_stats",
            "name",
            "age_range",
            "range_since_first_payment",
            "created_at_org",
            "country",
            "url_admin",
            "tags_routing",
            "gmv",
            "np_trx_last_30",
            "np_kyc_rejected",
            "np_clearsale_risk",
            "np_document",
            "confirmed_account",
            "ftp",
            "plan",
            "layout",
            "paid_until_at",
            "has_associated_partner",
            "has_instagram",
            "status",
        ] %}
    where
        existing_data.external_id is null
        {%- for col in monitored_cols %}
            or (info.{{ col }} is distinct from existing_data.{{ col }})
        {%- endfor %}
{% endif %}
