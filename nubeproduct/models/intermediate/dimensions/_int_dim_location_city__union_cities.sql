SELECT city_id_nk, city_name, state_id, region_id, country_id FROM (
SELECT 
a.city_id_nk, 
a.city_name, 
a.state_id,
COALESCE(c.region_id,-1) AS region_id,
b.id AS country_id,
ROW_NUMBER() OVER (PARTITION BY a.city_id_nk, b.id ORDER BY a.sys_audit_updated_on DESC) AS rnk
FROM
(
SELECT id AS city_id_nk, name AS city_name, province_id AS state_id, 'AR' AS country_code, sys_audit_updated_on FROM {{ source('int_moltres','mwp_cities_ar') }} UNION ALL
SELECT id AS city_id_nk, name AS city_name, province_id AS state_id, 'MX' AS country_code, sys_audit_updated_on FROM {{ source('int_moltres','mwp_cities_mx') }} UNION ALL
SELECT id AS city_id_nk, name AS city_name, province_id AS state_id, 'BR' AS country_code, sys_audit_updated_on FROM {{ source('int_moltres','cidades') }}
) a
LEFT JOIN {{ source('int_moltres','mwp_countries') }} b ON b.code = a.country_code
LEFT JOIN {{ ref('dimension__attributes__location_state__ref') }} AS c ON c.state_id = a.state_id AND c.country_id = b.id
) x WHERE rnk = 1