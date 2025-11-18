-- depends_on: {{ ref('orders__mwp_orders') }}
-- depends_on: {{ ref('orders__mwp_orders') }}
-- depends_on: {{ ref('orders__mwp_orders') }}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['fecha','step','store_id','storefront','device_type','gateway_method'],
        on_schema_change='fail',
        partition_by = 'fecha',
        tags=["daily-8am"]
    )
}}
WITH source AS (
    with base_data as(
    select
        cast(o.started_checkout_at as date) as fecha,
        o.store_id,
        o.storefront,
        o.device_type,
        o.gateway_method,
        o.status,
        o.payment_status,
        o.completed_contact_at,
        o.completed_at
    from data_products_prd.data_staging.orders__mwp_orders o
    where o.started_checkout_at >= date '2024-01-01'
        {% if is_incremental() %}
            and o.sys_audit_updated_on >= DATE_SUB( (SELECT COALESCE(MAX(fecha), DATE('1900-01-01')) FROM {{ this }}), 1 ) and o.started_checkout_at> DATE('2024-06-01')
        {% endif %}
    ), 
    final_table as(
        (select 
            o.fecha,
            'Started Checkout' as step,
            o.store_id,
            o.storefront,
            o.device_type,
            '' as gateway_method,
            count(*) as orders
        from base_data o
        group by 1,2,3,4,5,6
        )
        union all
        (
        select 
            o.fecha,
            'Completed Contact' as step,
            o.store_id,
            o.storefront,
            o.device_type,
            '' as gateway_method,
            count(completed_contact_at) as orders
        from base_data o
        group by 1,2,3,4,5,6
        )
        union all
        (
        select 
            o.fecha,
            'Completed Checkout' as step,
            o.store_id,
            o.storefront,
            o.device_type,
            o.gateway_method,
            count(completed_at) as orders
        from base_data o
        group by 1,2,3,4,5,6
        )
        union all
        (
        select 
            o.fecha,
            'Paid Order' as step,
            o.store_id,
            o.storefront,
            o.device_type,
            o.gateway_method,
            count(completed_at) as orders
        from base_data o
        where o.status <> 'cancelled' 
        and o.payment_status = 'paid' 
        group by 1,2,3,4,5,6
        )
        )
        select ft.*,
            si.current_segment_name,
            si.country_code
        from final_table ft
        left join data_products_prd.data_operations.company_metrics_merchant_info si on ft.store_id = si.store_id
),
    existing_data AS (
        {{ get_existing_data(this, ['fecha','step','store_id','storefront','device_type','gateway_method','orders', 'country_code', 'current_segment_name',
        'sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
    )
select
    coalesce(s.fecha, e.fecha) as fecha,
    coalesce(s.step, e.step) as step,
    coalesce(s.store_id, e.store_id) as store_id,
    coalesce(s.storefront, e.storefront) as storefront,
    coalesce(s.device_type, e.device_type) as device_type,
    coalesce(s.gateway_method, e.gateway_method) as gateway_method,
    coalesce(s.country_code, e.country_code) as country_code,
    coalesce(s.current_segment_name, e.current_segment_name) as current_segment_name,
    coalesce(s.orders, e.orders) as orders,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from source s
left join existing_data e on s.fecha = e.fecha
    and s.step = e.step
    and s.store_id = e.store_id
    and s.storefront = e.storefront
    and s.device_type = e.device_type
    and s.gateway_method = e.gateway_method
    and s.country_code = e.country_code
    and s.current_segment_name = e.current_segment_name