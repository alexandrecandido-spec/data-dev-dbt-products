-- ==============================================
-- QUERY 2/5: LOCATION INFORMATION (REGION/PROVINCE/CITY)
-- ==============================================
-- Esta query obtiene la información detallada de ubicación usando zipcode mapping
-- Join key: store_id

WITH 
-- Base de tiendas (filtro Argentina)
base_stores AS (
  SELECT id AS store_id
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4 AND country IN ('AR')
),

-- Shipping locations - Obtiene zipcode y ubicación desde shipping
shipping_locations AS (
  SELECT
    CAST(storeid AS BIGINT) AS store_id,
    address.country.code AS country_code,
    address.province.code AS state_code,
    address.zipcode AS zipcode
  FROM hive_metastore.shipping.locations
  WHERE address IS NOT NULL 
    AND chosenasdefaultat IS NOT NULL 
    AND deletedat IS NULL 
    AND isdraft = false
),

-- Zipcode to city mapping para Argentina
zipcode_cities AS (
  SELECT 
    zipcode, 
    city_id, 
    'AR' AS country_code 
  FROM hive_metastore.moltres.mwp_zipcodes_ar
  
  UNION ALL
  
  SELECT 
    zipcode, 
    city_id, 
    'MX' AS country_code 
  FROM hive_metastore.moltres.mwp_zipcodes_mx
  
  UNION ALL
  
  -- Para Brasil usa la tabla 'ceps' (latest per zipcode)
  SELECT 
    cep AS zipcode, 
    CAST(city_id AS BIGINT) AS city_id, 
    'BR' AS country_code 
  FROM (
    SELECT 
      cep, 
      city_id, 
      ROW_NUMBER() OVER(PARTITION BY cep ORDER BY sys_audit_updated_on DESC) AS rnk 
    FROM hive_metastore.moltres.ceps
  ) ranked_ceps
  WHERE rnk = 1
),

-- Location mapping - Combina shipping con zipcode info
location_mapping AS (
  SELECT 
    sl.store_id,
    sl.country_code,
    COALESCE(sl.state_code, 'Not Informed') AS state_code,
    COALESCE(zc.city_id, -1) AS city_id_nk
  FROM shipping_locations sl
  LEFT JOIN zipcode_cities zc 
    ON sl.zipcode = zc.zipcode 
    AND sl.country_code = zc.country_code
),

-- Country dimension
countries AS (
  SELECT 
    id AS country_id,
    code AS country_code,
    name AS country_name
  FROM hive_metastore.moltres.mwp_countries
),

-- State/Province dimension with region mapping
states_with_regions AS (
  SELECT 
    a.id AS state_id,
    a.code AS state_code,
    a.name AS state_name,
    a.country AS country_code,
    -- Region mapping based on dbt logic
    CASE
      -- Argentina regions  
      WHEN a.country = 'AR' AND a.code IN ('J','M','D') THEN 1 -- Cuyo
      WHEN a.country = 'AR' AND a.code IN ('BX','C') THEN 2 -- GBA+CABA
      WHEN a.country = 'AR' AND a.code IN ('P','H','N','W') THEN 3 -- NEA
      WHEN a.country = 'AR' AND a.code IN ('Y','A','K','F','T','G') THEN 4 -- NOA
      WHEN a.country = 'AR' AND a.code IN ('B','X','L','S','E') THEN 5 -- PAM
      WHEN a.country = 'AR' AND a.code IN ('Q','R','U','Z','V') THEN 6 -- PAT
      -- Brasil regions
      WHEN a.country = 'BR' AND a.code IN ('MT','MS','GO','DF') THEN 7 -- CO
      WHEN a.country = 'BR' AND a.code IN ('BA','SE','AL','PE','PB','RN','CE','MA','PI') THEN 8 -- NE
      WHEN a.country = 'BR' AND a.code IN ('RO','RR','AM','AP','PA','AC','TO') THEN 9 -- N
      WHEN a.country = 'BR' AND a.code IN ('MG','ES','RJ','SP') THEN 10 -- SE
      WHEN a.country = 'BR' AND a.code IN ('PR','SC','RS') THEN 11 -- S
      -- Mexico regions
      WHEN a.country = 'MX' AND a.code IN ('AGU','GUA','QUE','SLP','ZAC') THEN 12 -- BAJ
      WHEN a.country = 'MX' AND a.code IN ('CMX','MEX','MOR','HID','PUE','TLA') THEN 13 -- CTR
      WHEN a.country = 'MX' AND a.code IN ('COA','NLE','TAM') THEN 14 -- NOR
      WHEN a.country = 'MX' AND a.code IN ('BCN','BCS','CHH','DUR','SIN','SON') THEN 15 -- NORE
      WHEN a.country = 'MX' AND a.code IN ('COL','JAL','MIC','NAY') THEN 16 -- OEST
      WHEN a.country = 'MX' AND a.code IN ('CAM','ROO','TAB','YUC') THEN 17 -- SURE
      WHEN a.country = 'MX' AND a.code IN ('CHP','GRO','OAX','VER') THEN 18 -- SURO
      ELSE -1
    END AS region_id
  FROM hive_metastore.moltres.mwp_provinces a
),

-- Region names (manual mapping based on dbt seed)
regions AS (
  SELECT region_id, region_name, country_id FROM VALUES
    (1, 'Cuyo', 10),
    (2, 'Gran Buenos Aires + Ciudad Autónoma de Buenos Aires', 10),
    (3, 'Noreste Argentino', 10),
    (4, 'Noroeste Argentino', 10),
    (5, 'Pampeana', 10),
    (6, 'Patagonia', 10),
    (7, 'Centro-oeste', 30),
    (8, 'Nordeste', 30),
    (9, 'Norte', 30),
    (10, 'Sudeste', 30),
    (11, 'Sul', 30),
    (12, 'Bajio', 155),
    (13, 'Centro', 155),
    (14, 'Norte', 155),
    (15, 'Noroeste', 155),
    (16, 'Oeste', 155),
    (17, 'Sureste', 155),
    (18, 'Suroeste', 155)
  AS t(region_id, region_name, country_id)
),

-- Cities dimension (union of all countries)
cities AS (
  SELECT 
    id AS city_id_nk,
    name AS city_name,
    province_id AS state_id,
    'AR' AS country_code
  FROM hive_metastore.moltres.mwp_cities_ar
  
  UNION ALL
  
  SELECT 
    id AS city_id_nk,
    name AS city_name,
    province_id AS state_id,
    'MX' AS country_code
  FROM hive_metastore.moltres.mwp_cities_mx
  
  UNION ALL
  
  SELECT 
    id AS city_id_nk,
    name AS city_name,
    province_id AS state_id,
    'BR' AS country_code
  FROM hive_metastore.moltres.cidades
),

-- Final location enrichment
final_location AS (
  SELECT 
    lm.store_id,
    co.country_id,
    co.country_code,
    co.country_name,
    
    -- State/Province info
    COALESCE(sw.state_id, -1) AS state_id,
    sw.state_code,
    sw.state_name,
    
    -- Region info
    COALESCE(sw.region_id, -1) AS region_id,
    r.region_name,
    
    -- City info  
    COALESCE(ci.city_id_nk, -1) AS city_id,
    ci.city_name

  FROM location_mapping lm
  LEFT JOIN countries co ON lm.country_code = co.country_code
  LEFT JOIN states_with_regions sw ON sw.country_code = lm.country_code AND sw.state_code = lm.state_code
  LEFT JOIN regions r ON sw.region_id = r.region_id AND co.country_id = r.country_id
  LEFT JOIN cities ci ON ci.country_code = lm.country_code AND ci.city_id_nk = lm.city_id_nk AND ci.state_id = sw.state_id
)

-- Query final para join con otras tablas
SELECT 
  bs.store_id,
  
  -- Country info
  COALESCE(fl.country_code, 'AR') AS country_code,  -- Default AR
  fl.country_name,
  
  -- Location hierarchy  
  fl.region_name AS base_region_name,
  fl.state_name AS base_state_name,
  fl.city_name AS base_city_name,
  
  -- IDs for further joins if needed
  fl.country_id,
  fl.region_id,
  fl.state_id,
  fl.city_id

FROM base_stores bs
LEFT JOIN final_location fl ON bs.store_id = fl.store_id

ORDER BY bs.store_id
