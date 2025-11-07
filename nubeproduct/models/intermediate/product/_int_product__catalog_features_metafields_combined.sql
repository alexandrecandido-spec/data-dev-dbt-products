WITH variants_metafields AS (
    SELECT 
        store_id, 
        TRUE AS has_variants_metafields,
        MAX(pv.sys_audit_updated_on) AS vm_max_sys_audit_updated_on,
        COUNT(DISTINCT CASE WHEN value_type = 1 THEN uuid END) AS text_list_variants_metafield,
        COUNT(DISTINCT CASE WHEN value_type = 1 AND morpv.id IS NOT NULL THEN uuid END) AS text_list_variants_metafield_assigned,
        COUNT(DISTINCT CASE WHEN value_type = 2 THEN uuid END) AS text_variants_metafield,
        COUNT(DISTINCT CASE WHEN value_type = 2 AND mtrpv.id IS NOT NULL THEN uuid END) AS text_variants_metafield_assigned,
        COUNT(DISTINCT CASE WHEN value_type = 3 THEN uuid END) AS numeric_variants_metafield,
        COUNT(DISTINCT CASE WHEN value_type = 3 AND mnrpv.id IS NOT NULL THEN uuid END) AS numeric_variants_metafield_assigned,
        COUNT(DISTINCT CASE WHEN value_type = 4 THEN uuid END) AS date_variants_metafield,
        COUNT(DISTINCT CASE WHEN value_type = 4 AND mdrpv.id IS NOT NULL THEN uuid END) AS date_variants_metafield_assigned,
        COUNT(DISTINCT CASE WHEN value_type NOT IN (1,2,3,4) THEN uuid END) AS unknown_variants_metafield,
        COUNT(DISTINCT coalesce(mtrpv.owner_id, morpv.owner_id, mdrpv.owner_id, mnrpv.owner_id)) as variants_with_metafield_assigned_count
    FROM {{ ref('product__metafield__product_variants__event') }} pv
    LEFT JOIN {{ ref('product__metafield__text_resource_product_variants__event') }} mtrpv ON mtrpv.metafield_uuid = uuid
    LEFT JOIN {{ ref('product__metafield__numeric_resource_product_variants__event') }} mnrpv ON mnrpv.metafield_uuid = uuid
    LEFT JOIN {{ ref('product__metafield__option_resource_product_variants__event') }} morpv ON morpv.metafield_uuid = uuid
    LEFT JOIN {{ ref('product__metafield__date_resource_product_variants__event') }} mdrpv ON mdrpv.metafield_uuid = uuid
    WHERE deleted_at IS NULL
    GROUP BY store_id
),

products_metafields AS (
    SELECT 
        store_id,
        TRUE AS has_products_metafields,
        MAX(p.sys_audit_updated_on) AS pm_max_sys_audit_updated_on,
        COUNT(DISTINCT CASE WHEN value_type = 1 THEN uuid END) AS text_list_products_metafield,
        COUNT(DISTINCT CASE WHEN value_type = 1 AND morp.id IS NOT NULL THEN uuid END) AS text_list_products_metafield_assigned,
        COUNT(DISTINCT CASE WHEN value_type = 2 THEN uuid END) AS text_products_metafield,
        COUNT(DISTINCT CASE WHEN value_type = 2 AND mtrp.id IS NOT NULL THEN uuid END) AS text_products_metafield_assigned,
        COUNT(DISTINCT CASE WHEN value_type = 3 THEN uuid END) AS numeric_products_metafield,
        COUNT(DISTINCT CASE WHEN value_type = 3 AND mnrp.id IS NOT NULL THEN uuid END) AS numeric_products_metafield_assigned,
        COUNT(DISTINCT CASE WHEN value_type = 4 THEN uuid END) AS date_products_metafield,
        COUNT(DISTINCT CASE WHEN value_type = 4 AND mdrp.id IS NOT NULL THEN uuid END) AS date_products_metafield_assigned,
        COUNT(CASE WHEN value_type NOT IN (1,2,3,4) THEN uuid END) AS unknown_products_metafield,
        COUNT(DISTINCT coalesce(mtrp.owner_id, morp.owner_id, mdrp.owner_id, mnrp.owner_id)) as products_with_metafield_assigned_count
    FROM {{ ref('product__metafield__products__event') }} p
    LEFT JOIN {{ ref('product__metafield__date_resource_products__event') }} mdrp ON mdrp.metafield_uuid = uuid
    LEFT JOIN {{ ref('product__metafield__numeric_resource_products__event') }} mnrp ON mnrp.metafield_uuid = uuid
    LEFT JOIN {{ ref('product__metafield__option_resource_products__event') }} morp ON morp.metafield_uuid = uuid
    LEFT JOIN {{ ref('product__metafield__text_resource_products__event') }} mtrp ON mtrp.metafield_uuid = uuid
    WHERE deleted_at IS NULL
    GROUP BY store_id
)

SELECT
    COALESCE(vm.store_id, pm.store_id) AS store_id,
    vm.has_variants_metafields,
    vm.text_list_variants_metafield_assigned,
    vm.text_list_variants_metafield,
    vm.text_variants_metafield_assigned,
    vm.text_variants_metafield,
    vm.numeric_variants_metafield_assigned,
    vm.numeric_variants_metafield,
    vm.date_variants_metafield_assigned,
    vm.date_variants_metafield,
    vm.unknown_variants_metafield,
    pm.text_list_products_metafield_assigned,
    pm.has_products_metafields,
    pm.text_list_products_metafield_assigned,
    pm.text_list_products_metafield,
    pm.text_products_metafield_assigned,
    pm.text_products_metafield,
    pm.numeric_products_metafield_assigned,
    pm.numeric_products_metafield,
    pm.date_products_metafield_assigned,
    pm.date_products_metafield,
    pm.unknown_products_metafield,
    pm.products_with_metafield_assigned_count,
    vm.variants_with_metafield_assigned_count,
    GREATEST(
        COALESCE(vm.vm_max_sys_audit_updated_on, '1900-01-01'),
        COALESCE(pm.pm_max_sys_audit_updated_on, '1900-01-01')
    ) AS mf_max_sys_audit_updated_on
FROM variants_metafields vm
FULL OUTER JOIN products_metafields pm ON vm.store_id = pm.store_id
