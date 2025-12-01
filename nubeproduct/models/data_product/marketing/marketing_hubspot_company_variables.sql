{{
    config(
        materialized="incremental",
        unique_key="store_id",
        on_schema_change="sync_all_columns",
        incremental_strategy="merge",
        tags=["daily-8am"],
    )
}}

with
    source_data as (
        select
            coalesce(segment.segment_name, '') as status_by_order_str,
            coalesce(vertical.vertical_name, '') as vertical_str,
            'https://stats.tiendanube.com/store/profile?store_id='
            || active_stores.store_id as stats_url,
            coalesce(
                case
                    when country.country_code = 'BR'
                    then nullif(merchant.domain, '') || '.lojavirtualnuvem.com.br'
                    else nullif(merchant.domain, '') || '.mitiendanube.com'
                end,
                ''
            ) as website,
            coalesce(msi.partner_id, '') as associated_partner_id,
            coalesce(credit_limit.available_limit_admin, 0.0) as np_lending_available_credit,
            gmv.gmv_local_currency_on_platform_monthly,
            gmv.gmv_local_currency_on_platform_90d,
            layout.config_layout as config_layout_completed,
            products.config_products as config_products_completed,
            payments.config_payment as config_payment_completed,
            shipping.config_shipping as config_shipping_completed,
            -- New fields from marketing and merchants data products
            coalesce(country.country_code, '') as country,
            merchant.created_at,
            merchant.first_payment as first_payment_date,
            first_seller.first_seller_at as first_seller_date,
            admin_access.last_date_admin_access,
            storefront_sessions.last_store_session as last_date_sessions,
            lifecycle_status.current_plan_name as current_plan,
            coalesce(segment.segment_name, '') as current_segment,
            coalesce(store_info.user_email, '') as user_email,
            coalesce(store_info.phone_whatsapp_button, '') as whatsapp_button,
            coalesce(store_info.owner_phone_number, '') as owner_phone,
            gmv_rolling.gmv30 as gmv_last_30d,
            gmv_rolling.gmv60 as gmv_last_60d,
            gmv_rolling.gmv90 as gmv_last_90d,
            gmv_rolling.orders30 as orders_last_30d,
            gmv_rolling.orders60 as orders_last_60d,
            gmv_rolling.orders90 as orders_last_90d,
            active_stores.store_id
        from {{ ref("hubspot_active_stores") }} active_stores
        left join
            {{ ref("dim_merchant_info") }} merchant
            on active_stores.store_id = merchant.store_id
        left join
            {{ ref("dim_segment_type") }} segment
            on segment.segment_id = merchant.current_segment_id
        left join
            {{ ref("dim_vertical_type") }} vertical
            on vertical.vertical_id = merchant.vertical_id
        left join
            {{ ref("dim_location_country") }} country
            on country.country_id = merchant.country_id
        left join
            {{ ref("moltres__mwp_store_info") }} msi on msi.store_id = active_stores.store_id
        left join
            {{ ref("int_credit_last_available_limit") }} credit_limit
            on active_stores.store_id = credit_limit.store_id
        left join
            {{ ref("_int__midmarket__hubspot_gmv_by_store") }} gmv
            on active_stores.store_id = gmv.store_id
        left join
            {{ ref("s__product_marketing__layout__ref") }} layout
            on active_stores.store_id = layout.store_id
        left join
            {{ ref("s__product_marketing__products__ref") }} products
            on active_stores.store_id = products.store_id
        left join
            {{ ref("s__product_marketing__payments__ref") }} payments
            on active_stores.store_id = payments.store_id
        left join
            {{ ref("s__product_marketing__shipping__ref") }} shipping
            on active_stores.store_id = shipping.store_id
        left join
            {{ ref("marketing_first_seller_date") }} first_seller
            on active_stores.store_id = first_seller.store_id
        left join
            {{ ref("g__product_marketing__admin_access_store__agg") }} admin_access
            on active_stores.store_id = admin_access.store_id
        left join
            {{ ref("g__product_marketing__storefront_sessions_store__agg") }} storefront_sessions
            on active_stores.store_id = storefront_sessions.store_id
        left join
            {{ ref("s__lifecycle__store_status__ref") }} lifecycle_status
            on active_stores.store_id = lifecycle_status.store_id
        left join
            {{ ref("s__attributes__store_identity__ref") }} store_info
            on active_stores.store_id = store_info.store_id
        left join
            {{ ref("g__product_marketing__gmv_rolling_windows_store__agg") }} gmv_rolling
            on active_stores.store_id = gmv_rolling.store_id
    )

select
    info.store_id,
    info.status_by_order_str,
    info.vertical_str,
    info.stats_url,
    info.associated_partner_id,
    info.website,
    info.np_lending_available_credit,
    info.gmv_local_currency_on_platform_monthly,
    info.gmv_local_currency_on_platform_90d,
    info.config_layout_completed,
    info.config_products_completed,
    info.config_payment_completed,
    info.config_shipping_completed,
    -- New fields
    info.country,
    info.created_at,
    info.first_payment_date,
    info.first_seller_date,
    info.last_date_admin_access,
    info.last_date_sessions,
    info.current_plan,
    info.current_segment,
    info.user_email,
    info.whatsapp_button,
    info.owner_phone,
    info.gmv_last_30d,
    info.gmv_last_60d,
    info.gmv_last_90d,
    info.orders_last_30d,
    info.orders_last_60d,
    info.orders_last_90d,
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
        {{ this }} as existing_data on info.store_id = existing_data.store_id
        {% set monitored_cols = [
            "status_by_order_str",
            "vertical_str",
            "stats_url",
            "associated_partner_id",
            "website",
            "np_lending_available_credit",
            "gmv_local_currency_on_platform_monthly",
            "gmv_local_currency_on_platform_90d",
            "config_layout_completed",
            "config_products_completed",
            "config_payment_completed",
            "config_shipping_completed",
            "country",
            "created_at",
            "first_payment_date",
            "first_seller_date",
            "last_date_admin_access",
            "last_date_sessions",
            "current_plan",
            "current_segment",
            "user_email",
            "whatsapp_button",
            "owner_phone",
            "gmv_last_30d",
            "gmv_last_60d",
            "gmv_last_90d",
            "orders_last_30d",
            "orders_last_60d",
            "orders_last_90d"
        ] %}
    where
        existing_data.store_id is null
        {%- for col in monitored_cols %}
            or (info.{{ col }} is distinct from existing_data.{{ col }})
        {%- endfor %}
{% endif %}
