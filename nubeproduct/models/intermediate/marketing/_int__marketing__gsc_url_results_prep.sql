
WITH orig AS (
    SELECT
        CAST(date AS DATE) AS date,
        CAST(full_url AS STRING) AS full_url,
        CAST(path AS STRING) AS path,
        CAST(search_type AS STRING) AS search_type,
        CAST(country_name AS STRING) AS country_name,
        CAST(device AS STRING) AS device,
        SUM(CAST(impressions AS INT)) AS orig_impr,
        SUM(CAST(clicks AS INT)) AS orig_clicks,
        AVG(CAST(average_position AS FLOAT)) AS orig_pos
    FROM {{ source('int_third_party', 'marketing_google_search_console_urls_results') }}
    GROUP BY 1,2,3,4,5,6
),

unsplit AS (
    SELECT
        CAST(date AS DATE) AS date,
        CAST(full_url AS STRING) AS full_url,
        CAST(path AS STRING) AS path,
        CAST(search_type AS STRING) AS search_type,
        SUM(CAST(impressions AS INT)) AS unsplit_impr,
        SUM(CAST(clicks AS INT)) AS unsplit_clicks,
        AVG(CAST(position AS FLOAT)) AS unsplit_pos
    FROM {{ source('int_third_party', 'marketing_google_search_console_urls_unsplit_results') }}
    GROUP BY 1,2,3,4
),

orig_agg_for_join AS (
    SELECT
        date, full_url, path, search_type,
        SUM(orig_impr) as total_orig_impr,
        SUM(orig_clicks) as total_orig_clicks
    FROM orig
    GROUP BY 1,2,3,4
),

diffs AS (
    SELECT
        u.date,
        u.full_url,
        u.path,
        u.search_type,
        'Sin Identificar' AS country_name,
        'Sin Identificar' AS device,
        GREATEST(u.unsplit_impr - COALESCE(o.total_orig_impr, 0), 0) AS impressions,
        GREATEST(u.unsplit_clicks - COALESCE(o.total_orig_clicks, 0), 0) AS clicks,
        u.unsplit_pos AS average_position
    FROM unsplit u
    LEFT JOIN orig_agg_for_join o
        ON u.date = o.date 
        AND u.full_url = o.full_url 
        AND u.path = o.path 
        AND u.search_type = o.search_type
    WHERE (COALESCE(u.unsplit_impr, 0) - COALESCE(o.total_orig_impr, 0) > 0)
       OR (COALESCE(u.unsplit_clicks, 0) - COALESCE(o.total_orig_clicks, 0) > 0)
),

combined AS (
    SELECT 
        date, full_url, path, search_type, country_name, device, 
        orig_impr as impressions, orig_clicks as clicks, orig_pos as average_position
    FROM orig
    UNION ALL
    SELECT * FROM diffs
)

SELECT
    *,
    LOWER(REGEXP_REPLACE(full_url, '^(?:https?://)?(?:www\\.)?', '')) AS full_url_clean,
    SPLIT_PART(LOWER(REGEXP_REPLACE(full_url, '^(?:https?://)?(?:www\\.)?', '')), '/', 1) AS domain_clean,
    '/' || SUBSTR(
        LOWER(REGEXP_REPLACE(full_url, '^(?:https?://)?(?:www\\.)?', '')), 
        LENGTH(SPLIT_PART(LOWER(REGEXP_REPLACE(full_url, '^(?:https?://)?(?:www\\.)?', '')), '/', 1)) + 1
    ) AS path_clean,
    CAST(date_format(date, 'yyyyMMdd') AS INT) AS year_month_day_code
FROM combined