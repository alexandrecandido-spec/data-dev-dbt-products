-- Normalizes referral and landing domains by removing TLDs and common subdomains.
-- Produces clean domain names (e.g., 'facebook', 'instagram') for use in traffic attribution logic.


WITH base_domains AS (
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
   , ref_domain_raw
   , land_domain_raw
FROM
   {{ ref('_int_product__session_enriched_utms') }}
)


-- Remove final TLDs such as '.com', '.com.br', '.org.uk'
, cleaned_domains AS (
SELECT
   unique_session_key
   , REGEXP_REPLACE(ref_domain_raw, '(\\.[a-z]{2,3}){1,2}$', '') AS ref_domain_no_tld
   , REGEXP_REPLACE(land_domain_raw, '(\\.[a-z]{2,3}){1,2}$', '') AS land_domain_no_tld
FROM
   base_domains
)


-- Remove leading subdomains such as 'www.', 'm.', 'lm.'
, normalized_domains AS (
SELECT
   unique_session_key
   , REGEXP_REPLACE(ref_domain_no_tld, '^(www\\.|m\\.|l\\.|lm\\.)', '') AS ref_domain_clean
   , REGEXP_REPLACE(land_domain_no_tld, '^(www\\.|m\\.|l\\.|lm\\.)', '') AS land_domain_clean
FROM
   cleaned_domains
)


SELECT
   bd.unique_session_key
   , bd.session_timestamp
   , bd.base_date
   , bd.session_id
   , bd.consumer_id
   , bd.store_id
   , bd.visitor_country
   , bd.device
   , bd.theme
   , bd.user_agent
   , bd.ip_address
   , bd.utm_source
   , bd.utm_medium
   , bd.utm_campaign
   , bd.utm_term
   , bd.utm_content
   , bd.landing_page
   , bd.http_referral
   , NULLIF(nd.ref_domain_clean, '') AS ref_domain
   , NULLIF(nd.land_domain_clean, '') AS land_domain
FROM
   base_domains AS bd
LEFT JOIN
   normalized_domains AS nd
   ON bd.unique_session_key = nd.unique_session_key
