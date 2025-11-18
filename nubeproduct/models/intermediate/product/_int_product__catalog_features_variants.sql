WITH product_stock_info AS (
    SELECT
        p.id AS product_id,
        p.store_id,
        COUNT(DISTINCT CASE WHEN v.stock IS NULL THEN v.id END) AS variants_with_null_stock_count,
        COUNT(DISTINCT v.id) AS total_variants_count
    FROM {{ ref('product__mwp_product_list') }} p
    LEFT JOIN {{ ref('product__mwp_product_variants') }} v ON v.product_id = p.id AND v.deleted_at IS NULL
    WHERE p.deleted_at IS NULL
    GROUP BY p.id, p.store_id
),
product_variant_counts AS (
    SELECT
        p.store_id,
        MAX(case when rn = 1 then p.created_at end) AS first_product_created_at,
        MAX(case when rn = 6 then p.created_at end) AS sixth_product_created_at,
        MAX(CASE WHEN vd.id IS NOT NULL THEN TRUE ELSE FALSE END) AS store_used_video_uploads,
        COUNT(DISTINCT CASE WHEN p.deleted_at IS NULL THEN p.id END) AS product_count,
        COUNT(DISTINCT CASE WHEN p.deleted_at IS NULL AND p.publish = 1 THEN p.id END) AS published_product_count,
        COUNT(DISTINCT CASE WHEN p.deleted_at IS NULL AND p.publish = 1 AND requires_shipping = 1 THEN p.id END) AS published_physical_product_count,
        COUNT(DISTINCT CASE WHEN p.deleted_at IS NULL AND p.publish = 1 AND requires_shipping = 0 THEN p.id END) AS published_digital_product_count,
        COUNT(DISTINCT CASE WHEN p.deleted_at IS NULL AND video_url IS NOT NULL THEN p.id END) AS product_with_video_link_count,
        COUNT(DISTINCT CASE WHEN vd.id IS NOT NULL AND vd.deleted_at IS NULL THEN vd.id END) AS product_with_active_video_uploaded_count,
        COUNT(DISTINCT CASE WHEN psi.variants_with_null_stock_count = psi.total_variants_count AND psi.total_variants_count > 0 THEN p.id END) AS product_with_infinite_stock_count,
        COUNT(DISTINCT v.id) AS variant_count,
        COUNT(DISTINCT CASE WHEN p.publish = 1 THEN v.id END) AS published_product_variant_count,
        GREATEST(
            COALESCE(MAX(p.sys_audit_updated_on), '1900-01-01'),
            COALESCE(MAX(v.sys_audit_updated_on), '1900-01-01'),
            COALESCE(MAX(vd.sys_audit_updated_on), '1900-01-01')
        ) AS pvc_max_sys_audit_updated_on
    FROM (select *,row_number() over(partition by store_id order by created_at asc) as rn from {{ ref('product__mwp_product_list') }}) p 
    LEFT JOIN {{ ref('product__mwp_product_variants') }} v ON v.product_id = p.id
    LEFT JOIN {{ ref('product__mwp_product_videos') }} vd ON vd.product_id = p.id
    LEFT JOIN product_stock_info psi ON psi.product_id = p.id
    WHERE p.deleted_at IS NULL AND v.deleted_at IS NULL
    GROUP BY p.store_id
)

SELECT
    pvc.store_id,
    pvc.first_product_created_at,
    pvc.sixth_product_created_at,
    pvc.store_used_video_uploads,
    pvc.product_count,
    pvc.published_product_count,
    pvc.product_with_video_link_count,
    pvc.product_with_active_video_uploaded_count,
    pvc.variant_count,
    pvc.published_product_variant_count,
    pvc.product_with_infinite_stock_count,
    pvc.published_physical_product_count,
    pvc.published_digital_product_count,
    COALESCE(pvc.pvc_max_sys_audit_updated_on, '1900-01-01') AS sh_max_sys_audit_updated_on
FROM product_variant_counts pvc 
