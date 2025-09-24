-- Final materialized table
-- Consolidates shipments in Brazil + paid orders not linked to shipments.
-- Includes audit metadata (sys_audit_updated_on, sys_audit_updated_by).
-- Output: main unified dataset for orders and shipments, feeding dashboards and reports.

{{ 
    config(
        materialized='table', 
        on_schema_change='fail',
        tags = ["logistics", "daily-8am"]
    ) 
}}


WITH existing_data AS (
    {{ get_existing_data(this, ['shipment_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

base AS (
SELECT
    shipment_id,
    payment_status,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    completed_at,
    final_date,
    postage_label_creation_date,
    shipment_type,
    gsv,
    gmv,
    flg_gsv,
    flg_gmv,
    flg_shipment,
    flg_multicd,
    flg_ne_selected,
    flg_ne_enabled,
    selected_shipping_partner,
    delivery_shipping_partner,
    carriers,
    delivery_status,
    country
FROM {{ ref('_int_logistics_gsv__shipments') }}

UNION ALL

SELECT
    shipment_id,
    payment_status,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    completed_at,
    final_date,
    postage_label_creation_date,
    shipment_type,
    gsv,
    gmv,
    flg_gsv,
    flg_gmv,
    flg_shipment,
    flg_multicd,
    flg_ne_selected,
    flg_ne_enabled,
    selected_shipping_partner,
    delivery_shipping_partner,
    carriers,
    delivery_status,
    country
FROM {{ ref('_int_logistics_gsv__paid_orders') }}
)

SELECT
    b.*
    ,COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
    ,COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    ,current_timestamp AS sys_audit_updated_on
    ,'data-dev-dbt-products' AS sys_audit_updated_by
FROM base b
LEFT JOIN existing_data e
    ON b.shipment_id = e.shipment_id