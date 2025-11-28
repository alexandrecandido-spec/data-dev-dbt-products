-- _int__product__shipping__pickup_features

WITH ua as (

SELECT
    pb.store_id,
    pb.pickup_feature,
    pb.is_deleted,
    0 as max_km,
    0 as max_days_pickup,
    pb.pickup_locations_count

FROM {{ ref('_int__product__shipping__pickup_branch') }} pb

UNION ALL

SELECT
    pc.store_id,
    pc.pickup_feature,
    pc.is_deleted,
    0 as max_km,
    0 as max_days_pickup,
    pc.pickup_locations_count

FROM {{ ref('_int__product__shipping__pickup_custom') }} pc

UNION ALL

SELECT
    pp.store_id,
    pp.pickup_feature,
    pp.is_deleted,
    pp.max_km,
    pp.max_days_pickup,
    pp.pickup_locations_count

FROM {{ ref('_int__product__shipping__pickup_point') }} pp

),

final as (

SELECT
    ss.store_id,
    CASE WHEN ua.pickup_feature IS NULL THEN 'none' ELSE ua.pickup_feature END AS pickup_feature,
    CASE WHEN ua.is_deleted IS NULL THEN FALSE ELSE ua.is_deleted END AS is_deleted,
    CASE WHEN ua.max_km IS NULL THEN 0 ELSE ua.max_km END AS max_km,
    CASE WHEN ua.max_days_pickup IS NULL THEN 0 ELSE ua.max_days_pickup END AS max_days_pickup,
    CASE WHEN ua.pickup_locations_count IS NULL THEN 0 ELSE ua.pickup_locations_count END AS pickup_locations_count

FROM {{ ref('s__lifecycle__store_status__ref') }} ss

JOIN {{ ref('s__attributes__store_core__ref') }} sc
    ON sc.store_id = ss.store_id

LEFT JOIN ua
    ON ua.store_id = ss.store_id
)

SELECT
    store_id,
    pickup_feature,
    is_deleted,
    max_km,
    max_days_pickup,
    SUM(pickup_locations_count) AS pickup_locations_count

FROM final

GROUP BY 1, 2, 3, 4, 5