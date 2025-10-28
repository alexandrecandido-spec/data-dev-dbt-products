{{
    config(
        materialized        = "incremental",
        incremental_strategy= "merge",
        on_schema_change    = "sync_all_columns",
        tags                = ["daily-9am-9pm"],
        partition_by        = "year_month_day_code",
        unique_key          = "row_key"
    )
}}


with src as (
    select
        -- Dimensões da Loja
        o.store_id,
        o.country,
        o.domain,
        o.vertical,
        o.province,
        o.city,
        o.region,
        o.business_size,
        o.segment,
        o.nice_9_name,
        o.plan_group,
        o.bu,

        -- Dimensões do Pedido (por dia)
        o.date,
        o.year_month_day_code,
        o.mes,
        o.platform_type,
        o.storefront,
        o.device,
        o.payment_provider,
        o.payment_method,
        o.shipping_method,
        o.shipping_province,
        o.gateway_installments,
        o.order_source,
        o.social_network,
        o.source_details,
        o.source_type,

        -- Métricas
        o.gmv,
        o.gmv_usd,
        o.orders,
        o.orders_free_shipping,
        o.products
    from {{ ref('_int__operations__orders_gmv_store__agg_daily_prep') }} o
),

src_with_key as (
    select
        -- hash (varchar) em Trino: lower(hex(md5(...)))
        lower(hex(md5(concat_ws(
            '|',
            cast(store_id as varchar(10)),
            cast(country as varchar(10)),
            coalesce(domain, ''),
            coalesce(vertical, ''),
            coalesce(province, ''),
            coalesce(city, ''),
            coalesce(region, ''),
            coalesce(business_size, ''),
            coalesce(segment, ''),
            coalesce(nice_9_name, ''),
            coalesce(plan_group, ''),
            coalesce(bu, ''),
            cast(date as varchar(10)),
            cast(year_month_day_code as varchar(10)),
            cast(mes as varchar(10)),
            coalesce(platform_type, ''),
            coalesce(storefront, ''),
            coalesce(device, ''),
            coalesce(payment_provider, ''),
            coalesce(payment_method, ''),
            coalesce(shipping_method, ''),
            coalesce(shipping_province, ''),
            cast(gateway_installments as varchar(10)),
            coalesce(order_source, ''),
            coalesce(social_network, ''),
            coalesce(source_details, ''),
            cast(orders_free_shipping as varchar(10)),
            coalesce(source_type, '')
        )))) as row_key,
        *
    from src
),

final as (
    {% if is_incremental() %}
        select
            
            s.store_id,
            s.country,
            s.domain,
            s.vertical,
            s.province,
            s.city,
            s.region,
            s.business_size,
            s.segment,
            s.nice_9_name,
            s.plan_group,
            s.bu,

            s.date,
            s.year_month_day_code,
            s.mes,
            s.platform_type,
            s.storefront,
            s.device,
            s.payment_provider,
            s.payment_method,
            s.shipping_method,
            s.shipping_province,
            s.gateway_installments,
            s.order_source,
            s.social_network,
            s.source_details,
            s.source_type,

            s.gmv,
            s.gmv_usd,
            s.orders,
            s.orders_free_shipping,
            s.products,

            -- auditoria
            s.row_key,
            coalesce(t.sys_audit_created_on, current_timestamp) as sys_audit_created_on,
            coalesce(t.sys_audit_created_by, 'data-dev-dbt-products') as sys_audit_created_by,
            current_timestamp as sys_audit_updated_on,
            'data-dev-dbt-products' as sys_audit_updated_by
        from src_with_key s
        left join {{ this }} t
          on s.row_key = t.row_key

        {% set monitored_cols = ["orders", "gmv"] %}

        where
            t.row_key is null
            {%- for col in monitored_cols %}
              or (s.{{ col }} is distinct from t.{{ col }})
            {%- endfor %}

    {% else %}
        -- Primeira carga: insere tudo
        select
            
            s.store_id,
            s.country,
            s.domain,
            s.vertical,
            s.province,
            s.city,
            s.region,
            s.business_size,
            s.segment,
            s.nice_9_name,
            s.plan_group,
            s.bu,

            s.date,
            s.year_month_day_code,
            s.mes,
            s.platform_type,
            s.storefront,
            s.device,
            s.payment_provider,
            s.payment_method,
            s.shipping_method,
            s.shipping_province,
            s.gateway_installments,
            s.order_source,
            s.social_network,
            s.source_details,
            s.source_type,

            s.gmv,
            s.gmv_usd,
            s.orders,
            s.orders_free_shipping,
            s.products,

            -- auditoria
            s.row_key,
            current_timestamp as sys_audit_created_on,
            'data-dev-dbt-products' as sys_audit_created_by,
            current_timestamp as sys_audit_updated_on,
            'data-dev-dbt-products' as sys_audit_updated_by
        from src_with_key s
    {% endif %}
)

select * from final
