{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['feedback_id'],
    tags=['midmarket','daily-8am']
) }}

WITH deals AS (
  SELECT
      d.deal_id,
      d.country,
      d.dealname,
      d.deal_owner,
      CAST(d.go_live_real_date AS DATE)                                AS go_live_real_date,
      CAST(regexp_replace(d.last_survey_answered, '\\.0$', '') AS BIGINT) AS last_survey_answered,
      CASE
        WHEN fs2.feedback_id IS NOT NULL THEN
          DENSE_RANK() OVER (
            PARTITION BY fs2.feedback_id
            ORDER BY d.gmv_potencial DESC, d.deal_id
          )
        ELSE 1
      END AS feedbacks
  FROM {{ref('s__onboarding__pipeline__snapshot')}} d
  LEFT JOIN {{source('int_third_party', 'midmarket_hubspot_feedback_submissions')}} fs2
    ON CAST(regexp_replace(d.last_survey_answered, '\\.0$', '') AS BIGINT) = fs2.feedback_id
)
SELECT DISTINCT
    fs2.feedback_id,
    CAST(fs2.submission_timestamp AS DATE)                         AS date_submitted,
    fs2.name_and_website_of_the_store,
    fs2.survey_name,
    CAST(regexp_replace(fs2.value_product,            '\\.0$', '') AS INT) AS general_product_score,
    CAST(regexp_replace(fs2.value_xp_onboarding,      '\\.0$', '') AS INT) AS onboarding_experience_score,
    CAST(regexp_replace(fs2.value_tiendanube_growth,  '\\.0$', '') AS INT) AS tiendanube_helps_growth,
    CAST(regexp_replace(fs2.value_ref_tiendanube,     '\\.0$', '') AS INT) AS tiendanube_recommendation_probability,
    CAST(regexp_replace(fs2.experience_with_apps,     '\\.0$', '') AS INT) AS experience_with_apps,
    fs2.feedback_comments                                   AS extra_feedback,
    fs2.value_quality_hired_agency                          AS value_quality_hired_agency,
    fs2.value_quality_pro_serv                              AS value_quality_pro_serv,
    fs2.value_service_hired_agency                          AS value_service_hired_agency,
    fs2.value_service_pro_serv                              AS value_service_pro_serv,
    fs2.value_hired_agency_deadline                         AS value_hired_agency_deadline,
    fs2.value_pro_serv_deadline                             AS value_pro_serv_deadline,
    d.deal_id,
    d.country,
    d.dealname,
    d.deal_owner,
    d.go_live_real_date,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{source('int_third_party', 'midmarket_hubspot_feedback_submissions')}} fs2
LEFT JOIN (SELECT * FROM deals WHERE feedbacks = 1) d
  ON fs2.feedback_id = d.last_survey_answered
WHERE lower(fs2.survey_name) LIKE '%onboarding%';