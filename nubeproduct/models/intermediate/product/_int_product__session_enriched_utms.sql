-- Enriches filtered user sessions with fallback UTM parameters and referring/landing domains
-- UTM values are extracted from http_referral and landing_page if original UTMs are missing

WITH base_sessions AS (
SELECT
    unique_session_key
   , session_timestamp
   , base_date
   , session_id
   , consumer_id
   , store_id
   , visitor_country
   , device
   , theme
   , user_agent
   , ip_address
   , utm_source
   , utm_medium
   , utm_campaign
   , utm_term
   , utm_content
   , landing_page
   , http_referral
FROM
   {{ ref('product__traffic__sessions__event') }}
WHERE
   base_date {{
    get_max_date_env_model(
      'product',
      's__traffic__session__event',
      'base_date',
      1, 'day',
      fallback_start=None,
      fallback_end=None
    )
  }}
)

, utm_extracts AS (
SELECT
   unique_session_key
   , base_date

   -- UTMs from utm_source (quando o campo contém URL com parâmetros)
   , NULLIF(REGEXP_EXTRACT(utm_source, 'utm_source=([^&]+)', 1), '')   AS source_utm_source
   , NULLIF(REGEXP_EXTRACT(utm_source, 'utm_medium=([^&]+)', 1), '')   AS source_utm_medium
   , NULLIF(REGEXP_EXTRACT(utm_source, 'utm_campaign=([^&]+)', 1), '') AS source_utm_campaign
   , NULLIF(REGEXP_EXTRACT(utm_source, 'utm_term=([^&]+)', 1), '')     AS source_utm_term
   , NULLIF(REGEXP_EXTRACT(utm_source, 'utm_content=([^&]+)', 1), '')  AS source_utm_content


   -- UTMs from http_referral
   , NULLIF(REGEXP_EXTRACT(http_referral, 'utm_source=([^&]+)', 1), '')   AS ref_utm_source
   , NULLIF(REGEXP_EXTRACT(http_referral, 'utm_medium=([^&]+)', 1), '')   AS ref_utm_medium
   , NULLIF(REGEXP_EXTRACT(http_referral, 'utm_campaign=([^&]+)', 1), '') AS ref_utm_campaign
   , NULLIF(REGEXP_EXTRACT(http_referral, 'utm_term=([^&]+)', 1), '')     AS ref_utm_term
   , NULLIF(REGEXP_EXTRACT(http_referral, 'utm_content=([^&]+)', 1), '')  AS ref_utm_content


   -- UTMs from landing_page
   , NULLIF(REGEXP_EXTRACT(landing_page, 'utm_source=([^&]+)', 1), '')   AS land_utm_source
   , NULLIF(REGEXP_EXTRACT(landing_page, 'utm_medium=([^&]+)', 1), '')   AS land_utm_medium
   , NULLIF(REGEXP_EXTRACT(landing_page, 'utm_campaign=([^&]+)', 1), '') AS land_utm_campaign
   , NULLIF(REGEXP_EXTRACT(landing_page, 'utm_term=([^&]+)', 1), '')     AS land_utm_term
   , NULLIF(REGEXP_EXTRACT(landing_page, 'utm_content=([^&]+)', 1), '')  AS land_utm_content


   -- Domains
   , REGEXP_EXTRACT(http_referral, 'https?://([^/]+)', 1) AS ref_domain_raw
   , REGEXP_EXTRACT(landing_page, 'https?://([^/]+)', 1)  AS land_domain_raw
FROM
   base_sessions
)


SELECT
   bs.unique_session_key
   , bs.session_timestamp
   , bs.base_date
   , bs.session_id
   , bs.consumer_id
   , bs.store_id
   , bs.visitor_country
   , bs.device
   , bs.theme
   , bs.user_agent
   , bs.ip_address
   , COALESCE(ue.source_utm_source, bs.utm_source, ue.ref_utm_source, ue.land_utm_source)       AS utm_source
   , COALESCE(ue.source_utm_medium, bs.utm_medium, ue.ref_utm_medium, ue.land_utm_medium)       AS utm_medium
   , COALESCE(ue.source_utm_campaign, bs.utm_campaign, ue.ref_utm_campaign, ue.land_utm_campaign) AS utm_campaign
   , COALESCE(ue.source_utm_term, bs.utm_term, ue.ref_utm_term, ue.land_utm_term)             AS utm_term
   , COALESCE(ue.source_utm_content, bs.utm_content, ue.ref_utm_content, ue.land_utm_content)    AS utm_content
   , bs.landing_page
   , bs.http_referral
   , ue.ref_domain_raw
   , ue.land_domain_raw
FROM
   base_sessions AS bs
LEFT JOIN
   utm_extracts AS ue
   ON bs.unique_session_key = ue.unique_session_key
   AND bs.base_date = ue.base_date