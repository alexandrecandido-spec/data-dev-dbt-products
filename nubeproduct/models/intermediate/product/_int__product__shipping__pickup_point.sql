-- _int__product__shipping__pickup_point

SELECT
    CAST (pp.storeId as BIGINT) as store_id,
    CASE WHEN pp.isLocation = TRUE THEN 'cd as pickup point' ELSE 'pickup point' END AS pickup_feature,
    CASE WHEN (pp.createdAt > pp.deletedAt OR pp.deletedAt IS NULL) THEN FALSE ELSE TRUE END AS is_deleted,
    pp.range as max_km,
    pp.estimatedDeliveryTime.maxDays as max_days_pickup,
    COUNT(DISTINCT pp.id) AS pickup_locations_count

FROM {{ source('int_pickup_points', 'pickup_points') }} pp

GROUP BY 1, 2, 3, 4, 5