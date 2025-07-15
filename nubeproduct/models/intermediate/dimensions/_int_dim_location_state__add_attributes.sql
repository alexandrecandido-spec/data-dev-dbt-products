SELECT a.id AS state_id, a.code AS state_code, a.name AS state_name, COALESCE(region_id,-1) AS region_id, b.id as country_id
FROM   {{ source('int_moltres','mwp_provinces') }} a
LEFT   JOIN {{ source('int_moltres','mwp_countries') }} b ON a.country = b.code