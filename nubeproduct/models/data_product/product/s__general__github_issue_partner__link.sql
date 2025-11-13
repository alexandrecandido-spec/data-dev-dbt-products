{{ tier_by_prefix() }}
{{ 
  config(
    tags=['daily-9am'],
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id'],
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

WITH issues AS (
  SELECT *
  FROM {{ ref('_int__product__general__github_issues_and_problems_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
    AND is_latest_by_repo_and_number = TRUE
  {% if is_incremental() %}
  AND sys_audit_updated_on > (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP('1900-01-01 00:00:00')) - INTERVAL 24 HOURS
    FROM {{ this }}
  )
  {% endif %}
),
comments AS (
  SELECT *
  FROM {{ ref('_int__product__general__github_issues_and_problems_comments_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
  {% if is_incremental() %}
  AND sys_audit_updated_on > (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP('1900-01-01 00:00:00')) - INTERVAL 24 HOURS
    FROM {{ this }}
  )
  {% endif %}
),

-- Extraigo TODAS las ocurrencias desde comments
comments_radian AS (
  SELECT
    repo_name AS repo,
    number AS issue_number,
    id        AS comment_id,
    CAST(NULL AS STRING) AS issue_id,
    partner_id
  FROM comments
  LATERAL VIEW OUTER posexplode(regexp_extract_all(body, '(?:radian\\.linkedstore\\.com\\/partners\\/)(\\d+)', 1))
    AS pos, partner_id
),
comments_stats AS (
  SELECT
    repo_name AS repo,
    number AS issue_number,
    id AS comment_id,
    CAST(NULL AS STRING) AS issue_id,
    partner_id
  FROM comments
  LATERAL VIEW OUTER posexplode(regexp_extract_all(body, '(?:stats\\.tiendanube\\.com\\/partner\\/profile\\?id=)(\\d+)', 1))
    AS pos, partner_id
),

-- Y desde issues
issues_radian AS (
  SELECT
    repo_name AS repo,
    issue_number,
    CAST(NULL AS STRING) AS comment_id,
    CAST(id   AS STRING) AS issue_id,
    partner_id
  FROM issues
  LATERAL VIEW OUTER posexplode(regexp_extract_all(body, '(?:radian\\.linkedstore\\.com\\/partners\\/)(\\d+)', 1))
    AS pos, partner_id
),
issues_stats AS (
  SELECT
    repo_name AS repo,
    issue_number,
    CAST(NULL AS STRING) AS comment_id,
    CAST(id   AS STRING) AS issue_id,
    partner_id
  FROM issues
  LATERAL VIEW OUTER posexplode(regexp_extract_all(body, '(?:stats\\.tiendanube\\.com\\/partner\\/profile\\?id=)(\\d+)', 1))
    AS pos, partner_id
),

union_ids AS (
  SELECT * FROM comments_radian
  UNION ALL
  SELECT * FROM comments_stats
  UNION ALL
  SELECT * FROM issues_radian
  UNION ALL
  SELECT * FROM issues_stats
),

dedup AS (
  SELECT DISTINCT repo, issue_number, partner_id, comment_id, issue_id
  FROM union_ids
  WHERE partner_id IS NOT NULL AND partner_id <> ''
),

final AS (
  SELECT
    ABS(HASH(repo, issue_number, partner_id, COALESCE(comment_id,'-'), COALESCE(issue_id,'-'))) AS id,
    LOWER(repo) AS repo_name,
    issue_number,
    CAST(partner_id AS BIGINT) AS partner_id,
    comment_id,
    issue_id
  FROM dedup
),

existing_data AS (
  {{ get_existing_data(this, ['id','sys_audit_created_on','sys_audit_created_by']) }}
)

SELECT f.id, repo_name, issue_number, partner_id, comment_id, issue_id,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM final f
LEFT JOIN existing_data e ON f.id = e.id