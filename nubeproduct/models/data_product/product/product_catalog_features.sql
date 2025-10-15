{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

select
    store_id,
    domain,
    state,
    country,
    currency,
    current_segment,
    first_payment,
    plan_name,
    theme,
    avg_gmv_usd_last_3m,
    avg_orders_last_3m,
    enabled_languages_count,
    has_multi_language,
    enabled_countries_count,
    admin_stock_changes_count,
    api_stock_changes_count,
    csv_variant_creations_count,
    product_count,
    published_product_count,
    product_with_video_link_count,
    product_with_active_video_uploaded_count,
    variant_count,
    published_product_variant_count,
    used_video_uploads,
    active_with_stock_cd_count,
    active_cd_count,
    cd_count,
    category_count,
    category_level_count,
    has_variants_metafields,
    has_products_metafields,
    text_list_variants_metafield_count,
    text_variants_metafield_count,
    numeric_variants_metafield_count,
    date_variants_metafield_count,
    unknown_variants_metafield_count,
    text_list_products_metafield_count,
    text_products_metafield_count,
    numeric_products_metafield_count,
    date_products_metafield_count,
    unknown_products_metafield_count,
    created_at,
    churned_at,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int_product__catalog_features_store_properties') }} c

{% if is_incremental() %}
WHERE 
    c.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
{% endif %}