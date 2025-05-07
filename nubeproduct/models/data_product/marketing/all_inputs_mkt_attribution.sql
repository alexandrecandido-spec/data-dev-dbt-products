{{ config(
  materialized='table',
  unique_key=['id'],
  on_schema_change='fail',
  tags=["marketing", "attribution", "daily-4:30"]
) }}

SELECT
    git_utm.id,
    git_utm.input_number,
    git_utm.input_title,
    git_utm.utm_source,
    git_utm.utm_medium,
    git_utm.utm_campaign,
    NULL AS landing_page_domain,
    NULL AS landing_page_path,
    NULL AS partner_code,
    NULL AS referrer,
    git_utm.team,
    git_utm.subteam,
    NULL AS partner_id,
    NULL AS affiliate_code,
    NULL AS classification,
    NULL AS country,
    git_utm.user_create,
    git_utm.state,
    git_utm.created_at,
    git_utm.closed_at
FROM {{ ref('_int_utm_github_mkt_attribution') }} git_utm

UNION ALL

SELECT
    git_url.id,
    git_url.input_number,
    git_url.input_title,
    NULL AS utm_source,
    NULL AS utm_medium,
    NULL AS utm_campaign,
    git_url.landing_page_domain,
    git_url.landing_page_path,
    NULL AS partner_code,
    NULL AS referrer,
    git_url.team,
    git_url.subteam,
    NULL AS partner_id,
    NULL AS affiliate_code,
    NULL AS classification,
    NULL AS country,
    git_url.user_create,
    git_url.state,
    git_url.created_at,
    git_url.closed_at
FROM {{ ref('_int_url_insti_github_mkt_attribution') }} git_url

UNION ALL

SELECT
    git_subteam.id,
    git_subteam.input_number,
    git_subteam.input_title,
    git_subteam.utm_source,
    git_subteam.utm_medium,
    git_subteam.utm_campaign,
    NULL AS landing_page_domain,
    NULL AS landing_page_path,
    NULL AS partner_code,
    NULL AS referrer,
    git_subteam.team,
    git_subteam.subteam,
    NULL AS partner_id,
    NULL AS affiliate_code,
    NULL AS classification,
    NULL AS country,
    git_subteam.user_create,
    git_subteam.state,
    git_subteam.created_at,
    git_subteam.closed_at
FROM {{ ref('_int_subteam_github_mkt_attribution') }} git_subteam

UNION ALL

SELECT
    git_partner_exceptions.id,
    git_partner_exceptions.input_number,
    git_partner_exceptions.input_title,
    NULL AS utm_source,
    NULL AS utm_medium,
    NULL AS utm_campaign,
    NULL AS landing_page_domain,
    NULL AS landing_page_path,
    git_partner_exceptions.partner_code,
    NULL AS referrer,
    git_partner_exceptions.team,
    git_partner_exceptions.subteam,
    NULL AS partner_id,
    NULL AS affiliate_code,
    NULL AS classification,
    NULL AS country,
    git_partner_exceptions.user_create,
    git_partner_exceptions.state,
    git_partner_exceptions.created_at,
    git_partner_exceptions.closed_at
FROM {{ ref('_int_partner_exceptions_github_mkt_attribution') }} git_partner_exceptions

UNION ALL

SELECT
    git_fraud.id,
    git_fraud.input_number,
    git_fraud.input_title,
    NULL AS utm_source,
    NULL AS utm_medium,
    NULL AS utm_campaign,
    NULL AS landing_page_domain,
    NULL AS landing_page_path,
    git_fraud.partner_code,
    NULL AS referrer,
    NULL AS team,
    NULL AS subteam,
    git_fraud.partner_id,
    NULL AS affiliate_code,
    NULL AS classification,
    NULL AS country,
    git_fraud.user_create,
    git_fraud.state,
    git_fraud.created_at,
    git_fraud.closed_at
FROM {{ ref('_int_partner_fraud_github_mkt_attribution') }} git_fraud

UNION ALL

SELECT
    git_referrer.id,
    git_referrer.input_number,
    git_referrer.input_title,
    NULL AS utm_source,
    NULL AS utm_medium,
    NULL AS utm_campaign,
    NULL AS landing_page_domain,
    NULL AS landing_page_path,
    NULL AS partner_code,
    git_referrer.referrer,
    git_referrer.team,
    git_referrer.subteam,
    NULL AS partner_id,
    NULL AS affiliate_code,
    NULL AS classification,
    NULL AS country,
    git_referrer.user_create,
    git_referrer.state,
    git_referrer.created_at,
    git_referrer.closed_at
FROM {{ ref('_int_referrer_github_mkt_attribution') }} git_referrer

UNION ALL

SELECT
    git_affiliates.id,
    git_affiliates.input_number,
    git_affiliates.input_title,
    NULL AS utm_source,
    NULL AS utm_medium,
    NULL AS utm_campaign,
    NULL AS landing_page_domain,
    NULL AS landing_page_path,
    NULL AS partner_code,
    NULL AS referrer,
    NULL AS team,
    NULL AS subteam,
    NULL AS partner_id,
    git_affiliates.affiliate_code,
    git_affiliates.classification,
    git_affiliates.country,
    git_affiliates.user_create,
    git_affiliates.state,
    git_affiliates.created_at,
    git_affiliates.closed_at
FROM {{ ref('_int_affiliates_classification_github_mkt_attribution') }} git_affiliates