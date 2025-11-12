{{
  config(
    materialized='view'
  )
}}

WITH rice AS (
  SELECT * FROM {{ ref('_int__product__general__issues_summary_data_rice_values') }}
),

sections_raw AS (
  SELECT
    r.*,
    REGEXP_EXTRACT(r.body, '(?is)##\\s*Steps\\s*to\\s*reproduce\\s*##(.*?)(##|#\\s*Updates|$)', 1) AS steps_content,
    REGEXP_EXTRACT(r.body, '(?is)##\\s*Logs\\s*##(.*?)(##|#\\s*Updates|$)', 1) AS logs_content
  FROM rice r
)

SELECT
  repo_name,
  issue_number,
  id,
  labels_name,
  impact,
  confidence,
  effort,

  CASE
    WHEN steps_content IS NOT NULL
     AND LENGTH(REGEXP_REPLACE(TRIM(steps_content), '\\s+', ' ')) > 10
     AND NOT REGEXP_LIKE(steps_content, '(?i)A\\s*ser\\s*preenchido\\s*em\\s*uma\\s*segunda\\s*instancia\\s*pelo\\s*Tech\\s*Support\\s*-?\\s*Se\\s*nao\\s*tem\\s*excluir')
     AND NOT REGEXP_LIKE(steps_content, '(?i)Para\\s*completar\\s*en\\s*una\\s*segunda\\s*instancia\\s*por\\s*Tech\\s*Support,?\\s*si\\s*hay,?\\s*sino\\s*borrar')
  THEN TRUE ELSE FALSE END AS has_steps,

  CASE
    WHEN logs_content IS NOT NULL
     AND LENGTH(REGEXP_REPLACE(TRIM(logs_content), '\\s+', ' ')) > 10
     AND NOT REGEXP_LIKE(logs_content, '(?i)A\\s*ser\\s*preenchido\\s*em\\s*uma\\s*segunda\\s*instancia\\s*pelo\\s*Tech\\s*Support\\s*-?\\s*Se\\s*nao\\s*tem\\s*excluir')
     AND NOT REGEXP_LIKE(logs_content, '(?i)Para\\s*completar\\s*en\\s*una\\s*segunda\\s*instancia\\s*por\\s*Tech\\s*Support,?\\s*si\\s*hay,?\\s*sino\\s*borrar')
  THEN TRUE ELSE FALSE END AS has_logs
FROM sections_raw