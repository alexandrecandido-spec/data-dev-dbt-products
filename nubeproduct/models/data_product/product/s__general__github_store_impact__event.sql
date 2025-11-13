{{ tier_by_prefix() }}
{{
  config(
    tags=['daily-9am'],
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['issue_number','repo_name','comment_id'],
    on_schema_change='fail',
    post_hook=["
    DELETE FROM {{ this }}
    WHERE EXISTS (
      SELECT 1
      FROM {{ ref('product__general__github_issue_label__link') }} d
      WHERE d.sys_audit_is_deleted = 1
        AND d.repo_name   = {{ this }}.repo_name
        AND d.issue_number = {{ this }}.issue_number
    );
    ",
      "
      DELETE FROM {{ this }}
      WHERE EXISTS (
        SELECT 1
        FROM {{ ref('product__general__github_problem_label__link') }} d
        WHERE d.sys_audit_is_deleted = 1
          AND d.repo_name   = {{ this }}.repo_name
          AND d.issue_number = {{ this }}.issue_number
    );
      "]
  )
}}

WITH comments AS (
  SELECT *
  FROM {{ ref('_int__product__general__github_issues_and_problems_comments_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
),
issues AS (
  SELECT *
  FROM {{ ref('_int__product__general__github_issues_and_problems_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
    AND is_latest_by_repo_and_number = TRUE
),

impact_from_comments AS (
  SELECT
    repo_name,
    number AS issue_number,
    CASE
      WHEN regexp_like(REPLACE(LOWER(body), ' ', ''), '\\[x\\]dealbreaker') THEN 'dealbreaker'
      WHEN regexp_like(REPLACE(LOWER(body), ' ', ''), '\\[x\\](alto|alta)') THEN 'high'
      WHEN regexp_like(REPLACE(LOWER(body), ' ', ''), '\\[x\\](medio|médio)') THEN 'medium'
      WHEN regexp_like(REPLACE(LOWER(body), ' ', ''), '\\[x\\](bajo|baixo)') THEN 'low'
      ELSE NULL
    END AS impact,
    CAST(id AS STRING) AS comment_id
  FROM comments
),

impact_from_issues AS (
  SELECT
    repo_name,
    issue_number,
    CASE
      WHEN regexp_like(REPLACE(LOWER(body), ' ', ''), '\\[x\\]dealbreaker') THEN 'dealbreaker'
      WHEN regexp_like(REPLACE(LOWER(body), ' ', ''), '\\[x\\](alto|alta)') THEN 'high'
      WHEN regexp_like(REPLACE(LOWER(body), ' ', ''), '\\[x\\](medio|médio)') THEN 'medium'
      WHEN regexp_like(REPLACE(LOWER(body), ' ', ''), '\\[x\\](bajo|baixo)') THEN 'low'
      ELSE NULL
    END AS impact,
    CAST(-1 AS STRING) AS comment_id
  FROM issues
),

unioned AS (
  SELECT * FROM impact_from_comments
  UNION ALL
  SELECT * FROM impact_from_issues
),

filtered AS (
  SELECT
    repo_name,
    issue_number,
    impact,
    CASE WHEN comment_id IS NULL OR comment_id = '' THEN '-1' ELSE comment_id END AS comment_id
  FROM unioned
  WHERE impact IS NOT NULL AND impact <> ''
),

dedup AS (
  SELECT DISTINCT
    repo_name, issue_number, impact, comment_id
  FROM filtered
),

existing_data AS (
  {{ get_existing_data(this, ['issue_number','repo_name','comment_id','sys_audit_created_on','sys_audit_created_by']) }}
),

final AS (
  SELECT
    CAST(ABS(xxhash64(d.repo_name, d.issue_number, d.comment_id)) AS BIGINT) AS id,
    d.repo_name,
    d.issue_number,
    d.impact,
    d.comment_id,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
  FROM dedup d
  LEFT JOIN existing_data e
    ON d.repo_name = e.repo_name
   AND d.issue_number = e.issue_number
   AND d.comment_id = e.comment_id
)

SELECT *
FROM final
{% if is_incremental() %}
WHERE sys_audit_updated_on > (
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01 00:00:00') - INTERVAL 1 DAY
  FROM {{ this }}
)
{% endif %}
