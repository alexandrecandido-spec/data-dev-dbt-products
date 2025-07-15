WITH
 segment_base AS 
(
SELECT
 a.store_id
,a.datemonth AS dt
,COALESCE(b.segment_id,-1) AS segment_id
FROM {{ ref('company_metrics_gmv_and_segments') }} a
LEFT JOIN {{ ref('dim_segment_type') }} b on a.segment = b.segment_name
)
,latest_segment AS 
(
SELECT
 store_id
,segment_id as current_segment_id
,dt AS current_segment_date_id
,ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY dt DESC) AS rnk
FROM segment_base
),
max_segment AS 
(
SELECT 
 store_id
,segment_id AS max_segment_id
,dt AS max_segment_date_id
,ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY segment_id DESC, dt DESC) AS rnk
FROM segment_base
)
SELECT
 l.store_id
,l.current_segment_id
,l.current_segment_date_id
,m.max_segment_id
,m.max_segment_date_id
FROM  latest_segment l
INNER JOIN  max_segment m ON l.store_id = m.store_id
WHERE l.rnk = 1 AND m.rnk = 1