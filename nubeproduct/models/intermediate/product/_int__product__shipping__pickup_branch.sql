-- _int__product__shipping__pickup_branch

SELECT
    DISTINCT sb.store_id,
    'branch' as pickup_feature,
    CASE WHEN sb.deleted_at IS NULL THEN FALSE ELSE TRUE END AS is_deleted,
    COUNT(DISTINCT sb.id) AS pickup_locations_count

FROM {{ source('int_moltres', 'mwp_store_branches') }} sb

GROUP BY 1, 2, 3