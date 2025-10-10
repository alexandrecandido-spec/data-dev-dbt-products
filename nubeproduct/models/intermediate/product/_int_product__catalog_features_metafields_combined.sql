WITH variants_metafields AS (
    SELECT 
        store_id, 
        TRUE AS has_variants_metafields,
        MAX(sys_audit_updated_on) AS vm_max_sys_audit_updated_on,
        COUNT(CASE WHEN value_type = 1 THEN uuid END) AS text_list_variants_metafield,
        COUNT(CASE WHEN value_type = 2 THEN uuid END) AS text_variants_metafield,
        COUNT(CASE WHEN value_type = 3 THEN uuid END) AS numeric_variants_metafield,
        COUNT(CASE WHEN value_type = 4 THEN uuid END) AS date_variants_metafield,
        COUNT(CASE WHEN value_type NOT IN (1,2,3,4) THEN uuid END) AS unknown_variants_metafield
    FROM {{ ref('metafields__metafield_product_variants') }}
    WHERE deleted_at IS NULL
    GROUP BY store_id
),

products_metafields AS (
    SELECT 
        store_id,
        TRUE AS has_products_metafields,
        MAX(sys_audit_updated_on) AS pm_max_sys_audit_updated_on,
        COUNT(CASE WHEN value_type = 1 THEN uuid END) AS text_list_products_metafield,
        COUNT(CASE WHEN value_type = 2 THEN uuid END) AS text_products_metafield,
        COUNT(CASE WHEN value_type = 3 THEN uuid END) AS numeric_products_metafield,
        COUNT(CASE WHEN value_type = 4 THEN uuid END) AS date_products_metafield,
        COUNT(CASE WHEN value_type NOT IN (1,2,3,4) THEN uuid END) AS unknown_products_metafield
    FROM {{ ref('metafields__metafield_products') }}
    WHERE deleted_at IS NULL
    GROUP BY store_id
)

SELECT
    COALESCE(vm.store_id, pm.store_id) AS store_id,
    vm.has_variants_metafields,
    vm.text_list_variants_metafield,
    vm.text_variants_metafield,
    vm.numeric_variants_metafield,
    vm.date_variants_metafield,
    vm.unknown_variants_metafield,
    pm.has_products_metafields,
    pm.text_list_products_metafield,
    pm.text_products_metafield,
    pm.numeric_products_metafield,
    pm.date_products_metafield,
    pm.unknown_products_metafield,
    GREATEST(
        vm.vm_max_sys_audit_updated_on,
        pm.pm_max_sys_audit_updated_on
    ) AS mf_max_sys_audit_updated_on
FROM variants_metafields vm
FULL OUTER JOIN products_metafields pm ON vm.store_id = pm.store_id
