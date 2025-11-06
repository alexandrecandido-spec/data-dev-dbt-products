WITH stock_history AS (
    SELECT 
        store_id,
        MAX(sys_audit_updated_on) AS sh_max_sys_audit_updated_on,
        COUNT(CASE WHEN app_id IS NULL AND event = 'variant-stock-changed' THEN id END) AS store_admin_stock_changes,
        COUNT(CASE WHEN app_id IS NOT NULL AND event = 'variant-stock-changed' AND source IN ('api','admin_edit') THEN id END) AS store_api_stock_changes,
        COUNT(CASE WHEN event = 'variant-created' AND source IN ('csv_import') THEN id END) AS store_csv_variant_creations
    FROM {{ ref('product__mwp_stock_history') }}
    WHERE (
        SUBSTR(year_month_code, 1, 4) * 12 + SUBSTR(year_month_code, 5, 2)
    ) >= (
        YEAR(CURRENT_DATE) * 12 + MONTH(CURRENT_DATE) - 3
    )
    GROUP BY store_id
),

product_variant_counts AS (
    SELECT
        p.store_id,
        MAX(CASE WHEN vd.id IS NOT NULL THEN TRUE ELSE FALSE END) AS store_used_video_uploads,
        COUNT(DISTINCT CASE WHEN p.deleted_at IS NULL THEN p.id END) AS product_count,
        COUNT(DISTINCT CASE WHEN p.deleted_at IS NULL AND p.publish = 1 THEN p.id END) AS published_product_count,
        COUNT(DISTINCT CASE WHEN p.deleted_at IS NULL AND video_url IS NOT NULL THEN p.id END) AS product_with_video_link_count,
        COUNT(DISTINCT CASE WHEN vd.id IS NOT NULL AND vd.deleted_at IS NULL THEN vd.id END) AS product_with_active_video_uploaded_count,
        COUNT(DISTINCT v.id) AS variant_count,
        COUNT(DISTINCT CASE WHEN p.publish = 1 THEN v.id END) AS published_product_variant_count,
        GREATEST(
            COALESCE(MAX(p.sys_audit_updated_on), '1900-01-01'),
            COALESCE(MAX(v.sys_audit_updated_on), '1900-01-01'),
            COALESCE(MAX(vd.sys_audit_updated_on), '1900-01-01')
        ) AS pvc_max_sys_audit_updated_on
    FROM {{ ref('product__mwp_product_list') }} p 
    LEFT JOIN {{ ref('product__mwp_product_variants') }} v ON v.product_id = p.id
    LEFT JOIN {{ ref('product__mwp_product_videos') }} vd ON vd.product_id = p.id
    WHERE p.deleted_at IS NULL AND v.deleted_at IS NULL
    GROUP BY p.store_id
)

SELECT
    COALESCE(sh.store_id, pvc.store_id) AS store_id,
    sh.store_admin_stock_changes,
    sh.store_api_stock_changes,
    sh.store_csv_variant_creations,
    pvc.store_used_video_uploads,
    pvc.product_count,
    pvc.published_product_count,
    pvc.product_with_video_link_count,
    pvc.product_with_active_video_uploaded_count,
    pvc.variant_count,
    pvc.published_product_variant_count,
    GREATEST(
        COALESCE(sh.sh_max_sys_audit_updated_on, '1900-01-01'),
        COALESCE(pvc.pvc_max_sys_audit_updated_on, '1900-01-01')
    ) AS sh_max_sys_audit_updated_on
FROM stock_history sh
FULL OUTER JOIN product_variant_counts pvc ON sh.store_id = pvc.store_id
