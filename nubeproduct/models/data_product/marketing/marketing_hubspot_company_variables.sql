{{ config(
    materialized="incremental",
    unique_key="store_id",
    incremental_strategy='merge',
    tags=["daily-6am"]
) }}

WITH source_data AS (
    SELECT
        coalesce(segment.segment_name, '') as status_by_order_str,
        coalesce(vertical.vertical_name, '') as vertical_str,
        'https://stats.tiendanube.com/store/profile?store_id=' || merchant.store_id as stats_url,
        coalesce(msi.partner_id, '') as associated_partner_id,
        active_stores.store_id
    FROM {{ ref("hubspot_active_stores") }} active_stores
    LEFT JOIN
        {{ ref("dim_merchant_info") }} merchant
        ON active_stores.store_id = merchant.store_id
    LEFT JOIN
        {{ ref("dim_segment_type") }} segment
        ON segment.segment_id = merchant.current_segment_id
    LEFT JOIN
        {{ ref("dim_vertical_type") }} vertical
        ON vertical.vertical_id = merchant.vertical_id
    LEFT JOIN
        {{ ref("moltres__mwp_store_info") }} msi
        ON msi.store_id = merchant.store_id
)

SELECT
    info.store_id,
    info.status_by_order_str,
    info.vertical_str,
    info.stats_url,
    info.associated_partner_id,
    {% if is_incremental() %}
    coalesce(existing_data.sys_audit_created_on, current_timestamp) as sys_audit_created_on,
    coalesce(
        existing_data.sys_audit_created_by, 'data-dev-dbt-products'
    ) as sys_audit_created_by,
    {% else %}
    current_timestamp as sys_audit_created_on,
    'data-dev-dbt-products' as sys_audit_created_by,
    {% endif %}
    current_timestamp as sys_audit_updated_on,
    'data-dev-dbt-products' as sys_audit_updated_by
FROM
    source_data as info
{% if is_incremental() %}
LEFT JOIN
    {{ this }} as existing_data
    ON info.store_id = existing_data.store_id
WHERE
    existing_data.store_id IS NULL
    OR info.status_by_order_str <> existing_data.status_by_order_str
    OR info.vertical_str <> existing_data.vertical_str
    OR info.stats_url <> existing_data.stats_url
    OR info.associated_partner_id <> existing_data.associated_partner_id
{% endif %}
