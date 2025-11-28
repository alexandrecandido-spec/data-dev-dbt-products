WITH source_data AS (
    SELECT
        mpv_event_timestamp         AS event_timestamp,
        event_date_parsed           AS event_date,
        CAST(date_format(event_date_parsed, 'yyyyMMdd') AS INT) AS year_month_day_code,
        year_month_code,
        user_pseudo_id,
        unique_session,
        source                      AS source_ga4_classification,
        mpv_country                 AS original_user_country,
        mpv_env                     AS env_pagegroup,
        mpv_landing_page            AS landing_page,
        
        -- Regex traída de staging
        REGEXP_EXTRACT(COALESCE(mpv_landing_page, mpv_page), '^https?://([^/]+)', 1)       AS landing_page_domain,
        REGEXP_EXTRACT(COALESCE(mpv_landing_page, mpv_page), '^https?://[^/]+(/[^?]*)', 1) AS landing_page_path,

        mpv_last_source             AS last_source,
        mpv_last_medium             AS last_medium,
        mpv_last_campaign           AS last_campaign,

        -- Regex UTMs
        REGEXP_EXTRACT(COALESCE(mpv_landing_page, mpv_page), 'id_([^&]+)', 1)          AS utm_ad_id,
        REGEXP_EXTRACT(COALESCE(mpv_landing_page, mpv_page), 'utm_content=([^&]+)', 1) AS utm_content,
        REGEXP_EXTRACT(COALESCE(mpv_landing_page, mpv_page), 'utm_term=([^&]+)', 1)    AS utm_term,

        -- AUDITORÍA: Capturamos la fecha de actualización del origen
        sys_audit_updated_on

    FROM {{ ref('marketing_mod_pv_info') }}
    WHERE unique_session IS NOT NULL
      AND user_pseudo_id IS NOT NULL
      AND mpv_event_timestamp IS NOT NULL
     AND event_date_parsed >= DATE '2024-01-01'
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY unique_session
            ORDER BY event_timestamp
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY unique_session
        ) AS pageviews_per_session
    FROM source_data
)

SELECT
    event_timestamp,
    event_date,
    year_month_day_code,
    user_pseudo_id,
    unique_session,
    source_ga4_classification,
    original_user_country,
    env_pagegroup,
    landing_page,
    landing_page_domain,
    landing_page_path,
    last_source,
    last_medium,
    last_campaign,
    utm_ad_id,
    utm_content,
    utm_term,
    pageviews_per_session,
    CASE
        WHEN lower(landing_page) LIKE '%login%' THEN 'login'
        ELSE 'other'
    END AS landing_page_type,
    sys_audit_updated_on
FROM ranked
WHERE rn = 1
