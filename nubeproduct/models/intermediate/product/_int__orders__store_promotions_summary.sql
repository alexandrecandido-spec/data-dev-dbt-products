SELECT
    po.id,
    po.store_id,
    cast(po.completed_at as date) AS order_date,
    po.total_in_original_currency,
    po.total_in_usd,
    ss.current_segment AS store_segment,
    msi.country_code,
    ss.current_plan_type,
    -- Promotion type indicators
    CASE WHEN po.coupon_id IS NOT NULL AND po.discount_gateway > 0
        THEN TRUE ELSE FALSE END
        AS has_coupon,
    CASE WHEN po.coupon_id IS NOT NULL AND po.discount_gateway > 0 and mdc.coupon_created_by_app_id is not null
        THEN TRUE ELSE FALSE END
        AS has_app_coupon,
    CASE WHEN po.shipping_cost = 0 AND po.shipping_cost_owner IS NOT NULL AND po.shipping_extra LIKE '%"free_shipping"%'
        THEN TRUE ELSE FALSE END
        AS has_free_shipping,
    CASE WHEN po.shipping_cost = 0 AND po.shipping_cost_owner = 0 AND po.shipping_method LIKE '%Personalizado%'
        THEN TRUE ELSE FALSE END
        AS has_free_custom_shipping,
    CASE WHEN po.coupon_id IS NOT NULL AND po.discount_gateway = 0 AND po.shipping_cost = 0 AND po.shipping_cost_owner IS NOT NULL
        THEN TRUE ELSE FALSE END
        AS has_free_shipping_coupon,
    CASE WHEN po.shipping_cost = 0 AND po.shipping_cost_owner IS NOT NULL AND fsp.has_free_shipping_product IS TRUE
        THEN TRUE ELSE FALSE END
        AS has_product_with_free_shipping,
    CASE WHEN po.discount_gateway > 0
        THEN TRUE ELSE FALSE END
        AS has_payment_method_discount,
    CASE WHEN mpd.total_discount_amount > 0 AND (
        mpd.promotional_discount_contents LIKE '%"discount_script_type":"%x%"%'
        OR mpd.content_items LIKE '%"discount_script_type":"%x%"%'
    ) THEN TRUE ELSE FALSE END
        AS has_mxn,
    CASE WHEN mpd.total_discount_amount > 0 AND (
        mpd.promotional_discount_contents LIKE '%"discount_script_type":"NAtX%off"%'
        OR mpd.content_items LIKE '%"discount_script_type":"NAtX%off"%'
    ) THEN TRUE ELSE FALSE END
    AS has_quantity_discount,
    CASE WHEN mpd.total_discount_amount > 0 AND (
        mpd.promotional_discount_contents LIKE '%"discount_script_type":"custom"%'
        OR mpd.content_items LIKE '%"discount_script_type":"custom"%'
    ) THEN TRUE ELSE FALSE END
    AS has_application_discount,
    -- Audit fields: capture the maximum sys_audit_updated_on from all source tables
    GREATEST(
        COALESCE(po.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(mdc.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(mpd.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(fsp.max_sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(msi.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(ss.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
    ) AS sys_audit_updated_on
FROM
    {{ ref('s__orders__carts_orders_heads__events') }} po
LEFT JOIN {{ ref('product__coupon__discount_coupons__event') }} mdc ON po.coupon_id = mdc.coupon_id
LEFT JOIN {{ ref('product__orders__promotional_discounts__event') }} mpd ON po.id = mpd.order_id
LEFT JOIN (
    SELECT
        mop.order_id,
        TRUE AS has_free_shipping_product,
        MAX(mop.sys_audit_updated_on) AS max_sys_audit_updated_on
    FROM
        {{ ref('orders__mwp_order_products') }} mop
    WHERE
        mop.free_shipping = 1
    GROUP BY mop.order_id
) fsp ON po.id = fsp.order_id
LEFT JOIN {{ ref('s__attributes__store_core__ref') }} msi ON po.store_id = msi.store_id
LEFT JOIN {{ ref('s__lifecycle__store_status__ref') }} ss ON po.store_id = ss.store_id
WHERE flg_gmv = true