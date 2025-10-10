WITH 
orig_base AS (
  SELECT
    CAST(o.date AS DATE) AS date,
    o.full_url,
    o.path,
    o.search_type,
    SUM(o.impressions) AS orig_impr,
    SUM(o.clicks) AS orig_clicks,
    AVG(o.average_position) AS orig_pos
  FROM {{ ref('gsc__url_results') }} o
  GROUP BY 1,2,3,4
),

unsplit AS (
  SELECT
    CAST(u.date AS DATE) AS date,
    u.full_url,
    u.path,
    u.search_type,
    CAST(NULL AS STRING) AS device,
    CAST(NULL AS STRING) AS country_name,
    SUM(u.impressions) AS unsplit_impr,
    SUM(u.clicks) AS unsplit_clicks,
    AVG(u.average_position) AS unsplit_pos
  FROM {{ ref('gsc__url_unsplit_results') }} u
  GROUP BY 1,2,3,4
)
SELECT
  u.date,
  u.full_url,
  u.path,
  u.search_type,
  u.country_name,
  u.device,
  GREATEST(u.unsplit_impr - COALESCE(o.orig_impr, 0), 0) AS impressions,
  GREATEST(u.unsplit_clicks - COALESCE(o.orig_clicks, 0), 0) AS clicks,
  ROUND(u.unsplit_pos, 2) AS average_position
FROM unsplit u
LEFT JOIN orig_base o
  ON u.date = o.date
  AND u.full_url = o.full_url
  AND u.path = o.path
  AND u.search_type = o.search_type
WHERE 
  (COALESCE(u.unsplit_impr, 0) - COALESCE(o.orig_impr, 0) > 0)
  OR (COALESCE(u.unsplit_clicks, 0) - COALESCE(o.orig_clicks, 0) > 0)
  


