-- _int__product__shipping__pickup_custom

SELECT
    DISTINCT se.store_id,
    'custom' as pickup_feature,
    CASE WHEN se.deleted_at IS NULL THEN FALSE ELSE TRUE END AS is_deleted,
    COUNT(DISTINCT se.id) AS pickup_locations_count

FROM {{ source('int_moltres', 'mwp_table_shipping_entries') }} se

WHERE se.pickup_point = 1

GROUP BY 1, 2, 3