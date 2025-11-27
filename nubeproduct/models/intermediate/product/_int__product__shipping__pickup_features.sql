-- _int__product__shipping__pickup_features

SELECT
    pb.store_id,
    pb.pickup_feature,
    pb.is_deleted,
    'non applicable' as max_km,
    'non applicable' as max_days_pickup,
    pb.pickup_locations_count

FROM {{ ref('_int__product__shipping__pickup_branch') }} pb

UNION ALL

SELECT
    pc.store_id,
    pc.pickup_feature,
    pc.is_deleted,
    'non applicable' as max_km,
    'non applicable' as max_days_pickup,
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


