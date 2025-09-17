{{ config(
    materialized = 'table',
    tags = ['daily-10am']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['store_id','sys_audit_created_on','sys_audit_created_by']) }}
),

-- Base data operations
base_with_is_seller AS (
  SELECT
    b.store_id,
    b.created_at,
    b.country_code,
    b.country_name,
    b.base_country_code,
    b.base_country_name,
    b.base_region_name,
    b.base_state_name,
    b.base_city_name,
    b.current_segment_name,
    b.current_segment_date_id,
    b.max_segment_name,
    b.max_segment_date_id,
    b.vertical_name,
    b.business_size_name,
    b.group_name,
    b.domain,
    b.first_payment
  FROM {{ ref('company_metrics_merchant_info') }} b
)

SELECT
  -- base
  bws.store_id,
  bws.created_at,
  bws.country_code as country,
  bws.country_name,
  bws.base_country_code,
  bws.base_country_name,
  bws.base_region_name,
  bws.base_state_name,
  bws.base_city_name,
  bws.current_segment_name,
  bws.max_segment_name,
  bws.vertical_name,
  bws.business_size_name,
  bws.group_name,
  bws.domain,
  bws.first_payment,

  -- is_seller (3 estados coherentes con el schema)
  CASE
    WHEN bws.current_segment_name IS NULL
      OR lower(trim(bws.current_segment_name)) IN ('not informed','not_informed')
      THEN 'Not Informed'
    WHEN lower(trim(bws.current_segment_name)) IN ('no-seller','struggling-seller')
      THEN 'No-seller'
    ELSE 'Seller'
  END AS is_seller,

  -- attribution (desde _int_marketing_merchant_attribution)
  a.was_new_seller,
  a.first_seller_at,
  a.churned_at,
  a.mkt_source_first_click,
  a.mkt_subteam_first_click,
  a.mkt_source_last_click,
  a.mkt_subteam_last_click,
  a.mkt_campaign_first_click,
  a.mkt_campaign_last_click,
  a.mkt_landing_page_domain_first_click,
  a.mkt_landing_page_domain_last_click,
  a.mkt_landing_page_path_first_click,
  a.mkt_landing_page_path_last_click,
  a.mkt_register_url,
  a.blocked_fraud_tag,
  a.partner_id,
  a.partner_code,              
  a.partnership_type,

  -- ql & partners
  en.mkt_source_partner_click,
  en.mkt_subteam_partner_click,
  en.ql_profile,

  -- contacts
  s.main_user_id,
  s.email,
  s.phone,
  s.whatsapp,
  s.owner_phone,

  -- profile
  p.store_name,
  p.doc_type,
  p.doc_number,

  -- social
  s.instagram,
  s.instagram_followers,
  s.following,
  s.posts,
  s.posts_likes,
  s.facebook,
  s.twitter,
  s.tiktok,
  s.pinterest,

  -- sys_audit
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

FROM base_with_is_seller bws
LEFT JOIN {{ ref('_int_marketing_merchant_attribution') }} a USING (store_id)
LEFT JOIN {{ ref('_int_marketing_merchant_profile') }}     p USING (store_id)
LEFT JOIN {{ ref('_int_marketing_merchant_social_contacts') }}      s USING (store_id)
LEFT JOIN {{ ref('_int_marketing_merchant_ql_partners') }} en USING (store_id)
LEFT JOIN existing_data e USING (store_id);



