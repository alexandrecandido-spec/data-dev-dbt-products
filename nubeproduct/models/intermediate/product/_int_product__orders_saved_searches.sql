SELECT
    s.id AS saved_search_id,
    s.store_id,
    msi.state,
    msi.country,
    msi.currency,
    msi.current_segment,
    msi.first_payment,
    msi.churned_at,
    gp.grupo AS plan_name,
    msi.created_at AS merchant_created_at,
    s.user_id AS saved_search_user_id,
    s.name AS saved_search_name,
    s.position AS saved_search_position,
    s.default AS saved_search_default,
    s.hidden AS saved_search_hidden,
    DATE(s.created_at) AS saved_search_created_at,
    -- Handle NULL filter
    CASE WHEN s.filter IS NULL THEN 0 ELSE size(json_object_keys(s.filter)) END AS saved_search_number_of_keys,
    MAX(CASE WHEN parsed_json.key = 'page' THEN parsed_json.value ELSE NULL END) AS saved_search_page,
    MAX(CASE WHEN parsed_json.key = 'q' THEN parsed_json.value ELSE NULL END) AS saved_search_q,
    MAX(CASE WHEN parsed_json.key = 'perPage' THEN parsed_json.value ELSE NULL END) AS saved_search_per_page,
    MAX(CASE WHEN parsed_json.key = 'dateFrom' THEN parsed_json.value ELSE NULL END) AS saved_search_date_from,
    MAX(CASE WHEN parsed_json.key = 'dateTo' THEN parsed_json.value ELSE NULL END) AS saved_search_date_to,
    MAX(CASE WHEN parsed_json.key = 'status' THEN parsed_json.value ELSE NULL END) AS saved_search_status,
    MAX(CASE WHEN parsed_json.key = 'paymentStatus' THEN parsed_json.value ELSE NULL END) AS saved_search_payment_status,
    MAX(CASE WHEN parsed_json.key = 'fulfillmentStatus' THEN parsed_json.value ELSE NULL END) AS saved_search_fulfillment_status,
    MAX(CASE WHEN parsed_json.key = 'paymentMethods' THEN parsed_json.value ELSE NULL END) AS saved_search_payment_methods,
    MAX(CASE WHEN parsed_json.key = 'paymentProvider' THEN parsed_json.value ELSE NULL END) AS saved_search_payment_provider,
    MAX(CASE WHEN parsed_json.key = 'shippingMethod' THEN parsed_json.value ELSE NULL END) AS saved_search_shipping_method,
    MAX(CASE WHEN parsed_json.key = 'location' THEN parsed_json.value ELSE NULL END) AS saved_search_location,
    MAX(CASE WHEN parsed_json.key = 'origin' THEN parsed_json.value ELSE NULL END) AS saved_search_origin,
    MAX(CASE WHEN parsed_json.key = 'appId' THEN parsed_json.value ELSE NULL END) AS saved_search_appId,
    MAX(CASE WHEN parsed_json.key = 'products' THEN parsed_json.value ELSE NULL END) AS saved_search_products,
    MAX(CASE WHEN parsed_json.key = 'exactProductSet' THEN parsed_json.value ELSE NULL END) AS saved_search_exact_product_set,
    MAX(CASE WHEN parsed_json.key = 'minUnits' THEN parsed_json.value ELSE NULL END) AS saved_search_min_units,
    MAX(CASE WHEN parsed_json.key = 'maxUnits' THEN parsed_json.value ELSE NULL END) AS saved_search_max_units,
    MAX(CASE WHEN parsed_json.key = 'isWholesale' THEN parsed_json.value ELSE NULL END) AS saved_search_is_wholesale,
    MAX(CASE WHEN parsed_json.key = 'couponIdsRaw' THEN parsed_json.value ELSE NULL END) AS saved_search_coupon_ids_raw,
    MAX(CASE WHEN parsed_json.key = 'stockIssues' THEN parsed_json.value ELSE NULL END) AS saved_search_stock_issues,
    GREATEST(
        COALESCE(MAX(s.sys_audit_updated_on), '1900-01-01'),
        COALESCE(MAX(msi.sys_audit_updated_on), '1900-01-01'),
        COALESCE(MAX(gp.sys_audit_updated_on), '1900-01-01'),
        COALESCE(MAX(parsed_json.sys_audit_updated_on), '1900-01-01')
    ) AS max_sys_audit_updated_on
FROM {{ source('int_orders', 'order_saved_search') }} AS s
INNER JOIN {{ ref('moltres__mwp_store_info') }} msi ON msi.store_id = s.store_id
LEFT JOIN {{ ref('operations_grouping_plans') }} gp ON gp.plan = msi.plan
LEFT JOIN (
    SELECT
        id,
        sys_audit_updated_on,
        parsed_json_key AS key,
        parsed_json_value AS value
    FROM {{ source('int_orders', 'order_saved_search') }}
    LATERAL VIEW EXPLODE(from_json(filter, 'MAP<STRING, STRING>')) parsed_json AS parsed_json_key, parsed_json_value
) AS parsed_json ON s.id = parsed_json.id
GROUP BY
    s.id,
    s.store_id,
    msi.state,
    msi.country,
    msi.currency,
    msi.current_segment,
    msi.first_payment,
    msi.churned_at,
    gp.grupo,
    msi.created_at,
    s.user_id,
    s.name,
    s.position,
    s.default,
    s.hidden,
    s.created_at,
    s.filter
