WITH
 latest_vertifier AS
(
SELECT store_id, CASE WHEN vertifier IS NULL THEN 'Not Informed' WHEN vertifier IN ('','unknown') THEN 'Not Informed' ELSE vertifier END AS vertifier
FROM
(
SELECT store_id, vertifier, ROW_NUMBER() OVER(PARTITION BY store_id ORDER BY created_at DESC) AS rnk
FROM   {{ ref('antifraud_service__vertifier_store_inferences') }} 
) WHERE rnk = 1
)
SELECT 
 a.store_id
,b.vertical_id
FROM
(
SELECT store_id, vertical_name
FROM 
(
SELECT s.store_id, CASE WHEN s.type IS NULL THEN v.vertifier ELSE s.type END AS vertical_name
FROM      {{ source('dp_moltres','mwp_store_settings') }} s
LEFT JOIN latest_vertifier v ON v.store_id = s.store_id
) x 
WHERE vertical_name IS NOT NULL
) a LEFT JOIN {{ ref('dim_vertical_type') }} b on a.vertical_name = b.vertical_name