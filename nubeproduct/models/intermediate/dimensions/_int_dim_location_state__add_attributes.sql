SELECT state_id, state_code, state_name, region_id, country_id FROM (
SELECT state_id, state_code, state_name, region_id, country_id, ROW_NUMBER() OVER (PARTITION BY state_code, country_id ORDER BY sys_audit_updated_on DESC) AS rnk FROM (
SELECT 
a.id AS state_id, 
a.code AS state_code, 
a.name AS state_name, 
CASE
  WHEN a.country = 'AR' AND a.code IN ('J','M','D') THEN 1 -- ,"CUY","Cuyo",10
  WHEN a.country = 'AR' AND a.code IN ('BX','C') THEN 2 -- ,"GBA+CABA","Gran Buenos Aires + Ciudad Autónoma de Buenos Aires",10
  WHEN a.country = 'AR' AND a.code IN ('P','H','N','W') THEN 3 -- ,"NEA","Noreste Argentino",10
  WHEN a.country = 'AR' AND a.code IN ('Y','A','K','F','T','G') THEN 4 -- ,"NOA","Noroeste Argentino",10
  WHEN a.country = 'AR' AND a.code IN ('B','X','L','S','E') THEN 5 -- ,"PAM","Pampeana",10
  WHEN a.country = 'AR' AND a.code IN ('Q','R','U','Z','V') THEN 6 -- ,"PAT","Patagonia",10
  WHEN a.country = 'BR' AND a.code IN ('MT','MS','GO','DF') THEN 7 -- ,"CO","Centro-oeste",30
  WHEN a.country = 'BR' AND a.code IN ('BA','SE','AL','PE','PB','RN','CE','MA','PI') THEN 8 -- ,"NE","Nordeste",30
  WHEN a.country = 'BR' AND a.code IN ('RO','RR','AM','AP','PA','AC','TO') THEN 9 -- ,"N","Norte",30
  WHEN a.country = 'BR' AND a.code IN ('MG','ES','RJ','SP') THEN 10 -- ,"SE","Sudeste",30
  WHEN a.country = 'BR' AND a.code IN ('PR','SC','RS') THEN 11 -- ,"S","Sul",30
  WHEN a.country = 'MX' AND a.code IN ('AGU','GUA','QUE','SLP','ZAC') THEN 12 -- ,"BAJ","Bajio",155
  WHEN a.country = 'MX' AND a.code IN ('CMX','MEX','MOR','HID','PUE','TLA') THEN 13 -- ,"CTR","Centro",155
  WHEN a.country = 'MX' AND a.code IN ('COA','NLE','TAM') THEN 14 -- ,"NOR","Norte",155
  WHEN a.country = 'MX' AND a.code IN ('BCN','BCS','CHH','DUR','SIN','SON') THEN 15 -- ,"NORE","Noroeste",155
  WHEN a.country = 'MX' AND a.code IN ('COL','JAL','MIC','NAY') THEN 16 -- ,"OEST","Oeste",155
  WHEN a.country = 'MX' AND a.code IN ('CAM','ROO','TAB','YUC') THEN 17 -- ,"SURE","Sureste",155
  WHEN a.country = 'MX' AND a.code IN ('CHP','GRO','OAX','VER') THEN 18 -- ,"SURO","Suroeste",155
  ELSE -1
END AS region_id,
b.id as country_id,
a.sys_audit_updated_on
FROM   {{ source('int_moltres','mwp_provinces') }} a
LEFT   JOIN {{ source('int_moltres','mwp_countries') }} b ON a.country = b.code
) x
) x WHERE rnk = 1