WITH src AS (
    SELECT
        date,
        CAST(date_format(date, 'yyyyMMdd') AS INT)           AS year_month_day_code,
        source_ga4_classification,
        original_user_country,
        env,
        landing_page,
        landing_page_type,
        last_source,
        last_medium,
        last_campaign,
        utm_ad_id,
        utm_content,
        utm_term,
        first_event_device,
        last_event_device,
        only_login_session,
        login_in_session,
        user_type,
        engage,
        user_pseudo_id,
        unique_session,
        trial,
        payment,
        session_duration_minutes,
        pageviews_per_session

    FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}
)

SELECT
    src.*,

    /* ─── CLASSIFIED COUNTRY ─── */
    CASE
      WHEN date <= DATE '2024-09-07' THEN
        CASE
          WHEN source_ga4_classification = 'inst-br'
               OR (source_ga4_classification NOT LIKE '%inst%'
                   AND landing_page LIKE '%nuvemshop%') THEN 'BR'
          WHEN source_ga4_classification = 'inst-ar' THEN 'AR'
          WHEN source_ga4_classification = 'inst-mx' THEN 'MX'
          WHEN source_ga4_classification = 'inst-co' THEN 'CO'
          WHEN source_ga4_classification = 'inst-cl' THEN 'CL'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country = 'Argentina' THEN 'AR'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country = 'Mexico' THEN 'MX'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country = 'Chile' THEN 'CL'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country = 'Colombia' THEN 'CO'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country NOT IN ('Brazil','Mexico','Argentina','Chile','Colombia')
               THEN 'Other'
          ELSE original_user_country
        END
      ELSE
        CASE
          WHEN source_ga4_classification = 'inst-br'
               OR landing_page LIKE '%nuvemshop%' THEN 'BR'
          WHEN original_user_country = 'Argentina' THEN 'AR'
          WHEN original_user_country = 'Mexico'    THEN 'MX'
          WHEN original_user_country = 'Chile'     THEN 'CL'
          WHEN original_user_country = 'Colombia'  THEN 'CO'
          WHEN original_user_country NOT IN ('Brazil','Mexico','Argentina','Chile','Colombia')
               THEN 'Other'
          ELSE original_user_country
        END
    END AS classified_country

FROM src