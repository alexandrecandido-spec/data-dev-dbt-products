WITH
 sp AS 
(
SELECT
 CAST(storeid AS bigint) AS store_id
,address.country.code    AS country_code
,address.province.code   AS state_code
,address.zipcode         AS zipcode
,sys_audit_updated_on
FROM  {{ source('int_shipping','locations') }}
WHERE address IS NOT NULL 
AND   chosenasdefaultat IS NOT NULL 
AND   deletedat IS NULL 
AND   isdraft = false
)
,zip AS
(
select zipcode, city_id, 'AR' AS country_code FROM {{ source('int_moltres','mwp_zipcodes_ar') }} UNION ALL
select zipcode, city_id, 'MX' AS country_code FROM {{ source('int_moltres','mwp_zipcodes_mx') }} UNION ALL
select cep as zipcode, CAST(city_id AS bigint) AS city_id, 'BR' AS country_code FROM 
(
select cep, city_id, ROW_NUMBER() OVER(PARTITION BY cep ORDER BY sys_audit_updated_on DESC) AS rnk FROM {{ source('int_moltres','ceps') }}
) WHERE rnk = 1
)
,loc AS 
(
SELECT 
 s.store_id
,s.country_code
,COALESCE(s.state_code,'Not Informed') AS state_code
,COALESCE(z.city_id,-1) AS city_id_nk
,s.sys_audit_updated_on
FROM  sp s
LEFT JOIN zip z ON s.zipcode = z.zipcode AND s.country_code= z.country_code
)
select
 a.store_id
,COALESCE(b.country_id,-1) AS country_id
,COALESCE(c.state_id, d.state_id,-1) AS state_id
,COALESCE(c.region_id, d.region_id, -1) AS region_id
,COALESCE(d.city_id,   -1) AS city_id
,a.sys_audit_updated_on
from loc AS a
LEFT JOIN {{ ref('dim_location_country') }} AS b ON b.country_code = a.country_code
LEFT JOIN {{ ref('dim_location_state') }}   AS c ON c.country_id = b.country_id AND c.state_code = a.state_code
LEFT JOIN {{ ref('dim_location_city') }}    AS d ON d.country_id = b.country_id AND d.city_id_nk = a.city_id_nk