  SELECT
    CAST(o.date AS DATE) AS date,
    o.full_url,
    o.path,
    o.search_type,
    o.country_name,
    o.device,
    SUM(o.impressions) AS impressions,
    SUM(o.clicks) AS clicks,
    AVG(o.average_position) AS average_position
  FROM {{ ref('gsc__url_results') }} o
  GROUP BY 1,2,3,4,5,6
  