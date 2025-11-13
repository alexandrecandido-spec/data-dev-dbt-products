{{
  config(
    materialized='view'
  )
}}

WITH rs AS (
  SELECT * FROM {{ ref('_int__product__general__issues_summary_data_rice_sections') }}
)

SELECT
  repo_name,
  issue_number,
  id,
  CASE
    WHEN REGEXP_LIKE(LOWER(COALESCE(labels_name,'')), '(?i)(^|\\s)api(\\s|$)') THEN 'API'
    WHEN REGEXP_LIKE(LOWER(COALESCE(labels_name,'')), '(?i)(^|\\s)platform(\\s|$)') THEN 'PLATFORM DEVELOPMENT'
    ELSE 'NATIVE'
  END AS issue_type,
  impact,
  confidence,
  effort,
  has_steps,
  has_logs,
  CASE
    WHEN LOWER(COALESCE(labels_name,'')) LIKE '%quick fix%'
     AND LOWER(COALESCE(labels_name,'')) NOT LIKE '%no quick fix%'
    THEN TRUE ELSE FALSE END AS has_quickfix
FROM rs