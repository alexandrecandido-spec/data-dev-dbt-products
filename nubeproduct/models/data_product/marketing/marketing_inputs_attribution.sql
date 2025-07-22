{{ config(
  unique_key=['id'],
  on_schema_change='fail',
  tags=['daily-9am']
) }}

SELECT
    gi.id,
    gi.input_number,
    gi.input_title,
    CASE WHEN gi.issue_type IN ('UTM', 'SUBTEAM_MKT', 'REFERRER', 'PARTNER_CODE', 'PARTNER_FRAUD', 'AFFILIATE_LIST') THEN gi.issue_type
         WHEN gi.issue_type = 'URL' AND gi.url = 'nan' THEN 'INSTI' 
         WHEN gi.issue_type = 'URL' AND gi.url IS NOT NULL THEN 'URL' END AS input_type,
    CASE WHEN gi.utm_source = 'nan' THEN NULL ELSE gi.utm_source END AS utm_source,
    CASE WHEN gi.utm_medium = 'nan' THEN NULL ELSE gi.utm_medium END AS utm_medium,
    CASE WHEN gi.utm_campaign = 'nan' THEN NULL ELSE gi.utm_campaign END AS utm_campaign,
    CASE WHEN gi.utm_content = 'nan' THEN NULL ELSE gi.utm_content END AS utm_content,
    CASE WHEN gi.url = 'nan' THEN NULL ELSE gi.url END AS url,
    CASE WHEN gi.landing_page_domain = 'nan' THEN NULL ELSE gi.landing_page_domain END AS landing_page_domain,
    CASE WHEN gi.landing_page_path = 'nan' THEN NULL ELSE gi.landing_page_path END AS landing_page_path,
    CASE WHEN gi.referrer = 'nan' THEN NULL ELSE gi.referrer END AS referrer,
    CASE WHEN gi.partner_code = 'nan' THEN NULL ELSE gi.partner_code END AS partner_code,
    CASE WHEN gi.partner_id = 'nan' THEN NULL ELSE gi.partner_id END AS partner_id,
    CASE WHEN gi.fraude = 'nan' THEN NULL ELSE gi.fraude END AS fraude,
    CASE WHEN gi.affiliate_code = 'nan' THEN NULL ELSE gi.affiliate_code END AS affiliate_code,
    CASE WHEN gi.classification = 'nan' THEN NULL ELSE gi.classification END AS affiliate_classification,
    CASE WHEN gi.country = 'nan' THEN NULL ELSE gi.country END AS affiliate_country,
    CASE WHEN gi.tier = 'nan' THEN NULL ELSE gi.tier END AS affiliate_tier,
    CASE WHEN gi.fit = 'nan' THEN NULL ELSE gi.fit END AS affiliate_fit,
    CASE WHEN gi.main_platform = 'nan' THEN NULL ELSE gi.main_platform END AS affiliate_main_platform,
    CASE WHEN gi.team = 'Nan' THEN NULL ELSE gi.team END AS team,
    CASE WHEN gi.subteam = 'Nan' THEN NULL ELSE gi.subteam END AS subteam,
    gi.user_create,
    gi.state,
    gi.assignee,
    gi.comments,
    gi.created_at,
    gi.updated_at,
    gi.closed_at,
    gi.sys_audit_extracted_on,
    gi.sys_audit_created_on,
    gi.sys_audit_updated_on,
    gi.sys_audit_created_by, 
    gi.sys_audit_updated_by
FROM {{ ref('_int_marketing_inputs_attribution__explode') }} gi