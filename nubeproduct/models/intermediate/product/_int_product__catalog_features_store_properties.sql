select
    msi.store_id,
    msi.domain,
    msi.state,
    msi.country,
    msi.currency,
    msi.current_segment,
    CAST(msi.first_payment AS DATE) AS first_payment,
    combined.avg_gmv_usd_last_3m,
    combined.avg_orders_last_3m,
    gp.grupo plan_name,
    o.option_value theme,
    combined.store_enabled_languages AS enabled_languages_count,
    CASE WHEN combined.store_enabled_languages > 1 THEN 1 ELSE 0 END AS has_multi_language,
    combined.store_enabled_countries AS enabled_countries_count,
    spv.store_admin_stock_changes AS admin_stock_changes_count,
    spv.store_api_stock_changes AS api_stock_changes_count,
    spv.store_csv_variant_creations AS csv_variant_creations_count,
    spv.product_count AS product_count,
    spv.published_product_count AS published_product_count,
    spv.product_with_video_link_count AS product_with_video_link_count,
    spv.product_with_active_video_uploaded_count AS product_with_active_video_uploaded_count,
    spv.variant_count AS variant_count,
    spv.published_product_variant_count AS published_product_variant_count,
    spv.store_used_video_uploads AS used_video_uploads,
    combined.active_with_stock_cd_count AS active_with_stock_cd_count,
    combined.active_cd_count AS active_cd_count,
    combined.cd_count AS cd_count,
    combined.category_count AS category_count,
    combined.category_level_count AS category_level_count, 
    mf.has_variants_metafields AS has_variants_metafields,
    mf.has_products_metafields AS has_products_metafields,
    mf.text_list_variants_metafield AS text_list_variants_metafield_count,
    mf.text_list_variants_metafield_assigned AS text_list_variants_metafield_assigned_count,
    mf.text_variants_metafield AS text_variants_metafield_count,
    mf.text_variants_metafield_assigned AS text_variants_metafield_assigned_count,
    mf.numeric_variants_metafield AS numeric_variants_metafield_count,
    mf.numeric_variants_metafield_assigned AS numeric_variants_metafield_assigned_count,
    mf.date_variants_metafield AS date_variants_metafield_count,
    mf.date_variants_metafield_assigned AS date_variants_metafield_assigned_count,
    mf.unknown_variants_metafield AS unknown_variants_metafield_count,
    mf.text_list_products_metafield AS text_list_products_metafield_count,
    mf.text_list_products_metafield_assigned AS text_list_products_metafield_assigned_count,
    mf.text_products_metafield AS text_products_metafield_count,
    mf.text_products_metafield_assigned AS text_products_metafield_assigned_count,
    mf.numeric_products_metafield AS numeric_products_metafield_count,
    mf.numeric_products_metafield_assigned AS numeric_products_metafield_assigned_count,
    mf.date_products_metafield AS date_products_metafield_count,
    mf.date_products_metafield_assigned AS date_products_metafield_assigned_count,
    mf.unknown_products_metafield AS unknown_products_metafield_count,
    mf.products_with_metafield_assigned_count,
    mf.variants_with_metafield_assigned_count,
    CAST(msi.created_at AS DATE) AS created_at,
    CAST(msi.churned_at AS DATE) AS churned_at,
    GREATEST(
        COALESCE(spv.sh_max_sys_audit_updated_on, '1900-01-01'),
        COALESCE(combined.c_max_sys_audit_updated_on, '1900-01-01'),
        COALESCE(mf.mf_max_sys_audit_updated_on, '1900-01-01')
    ) AS max_sys_audit_updated_on
FROM {{ ref('moltres__mwp_store_info') }} msi
LEFT JOIN {{ ref('operations_grouping_plans') }} gp on gp.plan = msi.plan
LEFT JOIN 
    (
        SELECT
            store_id,
            option_value
        FROM {{ source('int_moltres', 'mwp_options') }}
        WHERE option_name = 'twig_template'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY created_at DESC) = 1
    ) o 
ON o.store_id = msi.store_id
LEFT JOIN {{ ref('_int_product__catalog_features_stock_history_variants') }} spv on spv.store_id = msi.store_id
LEFT JOIN {{ ref('_int_product__catalog_features_categories_lang_cd_gmv') }} combined on combined.store_id = msi.store_id
LEFT JOIN {{ ref('_int_product__catalog_features_metafields_combined') }} mf on mf.store_id = msi.store_id

