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
        AND is_latest_by_repo_and_number = TRUE
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
          AND is_latest_by_repo_and_number = TRUE
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
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP('1900-01-01 00:00:00')) - INTERVAL 1 HOURS
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
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP('1900-01-01 00:00:00')) - INTERVAL 1 HOURS
    FROM {{ this }}
  )
  {% endif %}
),

comments_zendesk AS (
  SELECT
    repo_name AS repo,
    number    AS issue_number,
    id        AS comment_id,
    CAST(NULL AS STRING) AS issue_id,
    zendesk_id,
    CAST(created_at AS TIMESTAMP) AS issue_or_comment_created_at,
    'comment' AS source
  FROM comments
  LATERAL VIEW OUTER posexplode(
    regexp_extract_all(
      body,
      '(?:tiendanubehelp\\.zendesk\\.com\\/agent(?:\\/\\#)?\\/tickets\\/)(\\d+)',
      1
    )
  ) AS pos, zendesk_id
),

issues_zendesk AS (
  SELECT
    repo_name AS repo,
    issue_number,
    CAST(NULL AS STRING) AS comment_id,
    CAST(id   AS STRING) AS issue_id,
    zendesk_id,
    CAST(created_at AS TIMESTAMP) AS issue_or_comment_created_at,
    'issue' AS source
  FROM issues
  LATERAL VIEW OUTER posexplode(
    regexp_extract_all(
      body,
      '(?:tiendanubehelp\\.zendesk\\.com\\/agent(?:\\/\\#)?\\/tickets\\/)(\\d+)',
      1
    )
  ) AS pos, zendesk_id
),

union_ids AS (
  SELECT * FROM comments_zendesk
  UNION ALL
  SELECT * FROM issues_zendesk
),

dedup AS (
  SELECT DISTINCT
    repo,
    issue_number,
    zendesk_id,
    comment_id,
    issue_id,
    issue_or_comment_created_at,
    source
  FROM union_ids
  WHERE zendesk_id IS NOT NULL AND zendesk_id <> ''
),

final AS (
  SELECT
    sha2(
      concat_ws('||',
        lower(repo),
        cast(issue_number as string),
        cast(zendesk_id as string),
        coalesce(cast(comment_id as string), '-'),
        coalesce(cast(issue_id   as string), '-')
      ), 256
    ) AS id,
    LOWER(repo) AS repo_name,
    issue_number,
    CAST(zendesk_id AS BIGINT) AS zendesk_id,
    comment_id,
    issue_id,
    issue_or_comment_created_at,
    source
  FROM dedup
),

existing_data AS (
  {{ get_existing_data(this, ['id','sys_audit_created_on','sys_audit_created_by']) }}
)

SELECT
  f.id,
  repo_name,
  issue_number,
  zendesk_id,
  comment_id,
  issue_id,
  f.issue_or_comment_created_at,
  f.source AS source,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM final f
LEFT JOIN existing_data e ON f.id = e.id
