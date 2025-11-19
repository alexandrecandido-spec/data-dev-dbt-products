{{
    config(
        materialized="incremental",
        unique_key="store_id",
        on_schema_change="sync_all_columns",
        incremental_strategy="merge",
        tags=["daily-6am"],
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
            -- 4 Steps de Onboarding
            coalesce(layout.config_layout, 0) as config_layout,
            layout.first_date_config_layout,
            layout.last_date_config_layout,
            coalesce(payments.config_payment, 0) as config_payment,
            payments.first_date_config_payment,
            payments.last_date_config_payment,
            coalesce(shipping.config_shipping, 0) as config_shipping,
            shipping.first_date_config_shipping,
            shipping.last_date_config_shipping,
            coalesce(products.config_products, 0) as config_products,
            products.first_date_config_products,
            products.last_date_config_products,
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
            {{ ref("s__product_marketing__payments__ref") }} payments
            on active_stores.store_id = payments.store_id
        left join
            {{ ref("s__product_marketing__shipping__ref") }} shipping
            on active_stores.store_id = shipping.store_id
        left join
            {{ ref("s__product_marketing__products__ref") }} products
            on active_stores.store_id = products.store_id
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
    -- 4 Steps de Onboarding
    info.config_layout,
    info.first_date_config_layout,
    info.last_date_config_layout,
    info.config_payment,
    info.first_date_config_payment,
    info.last_date_config_payment,
    info.config_shipping,
    info.first_date_config_shipping,
    info.last_date_config_shipping,
    info.config_products,
    info.first_date_config_products,
    info.last_date_config_products,
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
            "config_layout",
            "first_date_config_layout",
            "last_date_config_layout",
            "config_payment",
            "first_date_config_payment",
            "last_date_config_payment",
            "config_shipping",
            "first_date_config_shipping",
            "last_date_config_shipping",
            "config_products",
            "first_date_config_products",
            "last_date_config_products"
        ] %}
    where
        existing_data.store_id is null
        {%- for col in monitored_cols %}
            or (info.{{ col }} is distinct from existing_data.{{ col }})
        {%- endfor %}
{% endif %}
