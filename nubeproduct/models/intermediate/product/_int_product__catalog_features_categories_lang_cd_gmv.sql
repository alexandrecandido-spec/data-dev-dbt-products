WITH category_counts AS (
    SELECT 
        store_id,
        COUNT(DISTINCT id) AS category_count,
        MAX(sys_audit_updated_on) AS mpc_max_sys_audit_updated_on,
        MAX((LENGTH(matpath) - LENGTH(REPLACE(matpath, '/', '')))) AS category_level_count
    FROM {{ ref('product__mwp_product_categories')}}
    WHERE deleted_at IS NULL 
    GROUP BY store_id
),

cd_counts AS (
    SELECT 
        l.storeid AS store_id,
        GREATEST(
            MAX(l.sys_audit_updated_on),
            MAX(il.sys_audit_updated_on)
        ) AS l_max_sys_audit_updated_on,
        COUNT(DISTINCT l.id) AS cd_count,
        COUNT(DISTINCT CASE WHEN l.deletedAt IS NULL THEN l.id END) AS active_cd_count,
        COUNT(DISTINCT CASE WHEN l.deletedAt IS NULL AND il.id IS NOT NULL THEN l.id END) AS active_with_stock_cd_count
    FROM {{ ref('product__shipping_locations') }} l
    LEFT JOIN {{ ref('product__mwp_inventory_levels') }} il ON l.id = il.location_id AND il.deleted_at IS NULL
    GROUP BY l.storeid
),

gmv_orders AS (
    SELECT
        store_id,
        MAX(sys_audit_updated_on) AS gmv_max_sys_audit_updated_on,
        ROUND(AVG(gmv_usd_monthly), 2) AS avg_gmv_usd_last_3m,
        ROUND(AVG(orders_monthly)) AS avg_orders_last_3m
    FROM {{ ref('company_metrics_gmv_and_segments')}}
    WHERE TRUNC(datemonth, 'MM') BETWEEN ADD_MONTHS(TRUNC((SELECT MAX(datemonth) FROM {{ ref('company_metrics_gmv_and_segments')}}), 'MM'), -2)
        AND TRUNC((SELECT MAX(datemonth) FROM {{ ref('company_metrics_gmv_and_segments')}}), 'MM')
    GROUP BY store_id
),

language_countries AS (
    SELECT 
        l.store_id,
        GREATEST(
            MAX(l.sys_audit_updated_on),
            MAX(uc.sys_audit_updated_on)
        ) AS lc_max_sys_audit_updated_on,   
        count(distinct CASE WHEN l.active = 1 THEN l.id END) store_enabled_languages,
        count(distinct CASE WHEN l.active = 1 THEN uc.id END) store_enabled_countries
    FROM {{ ref('moltres__mwp_user_languages')}}  l
    LEFT JOIN {{ ref('moltres__mwp_user_countries')}} uc ON l.store_id = uc.store_id
    GROUP BY 1
)

SELECT
    COALESCE(cc.store_id, cd.store_id, gm.store_id, lc.store_id) AS store_id,
    cc.category_count,
    cc.category_level_count,
    cd.cd_count,
    cd.active_cd_count,
    cd.active_with_stock_cd_count,
    gm.avg_gmv_usd_last_3m,
    gm.avg_orders_last_3m,
    lc.store_enabled_languages,
    lc.store_enabled_countries,
    GREATEST(
        cc.mpc_max_sys_audit_updated_on,
        cd.l_max_sys_audit_updated_on,
        gm.gmv_max_sys_audit_updated_on,
        lc.lc_max_sys_audit_updated_on
    ) AS c_max_sys_audit_updated_on
FROM category_counts cc
FULL OUTER JOIN cd_counts cd ON cc.store_id = cd.store_id
FULL OUTER JOIN gmv_orders gm ON COALESCE(cc.store_id, cd.store_id) = gm.store_id
FULL OUTER JOIN language_countries lc ON COALESCE(cc.store_id, cd.store_id, gm.store_id) = lc.store_id
