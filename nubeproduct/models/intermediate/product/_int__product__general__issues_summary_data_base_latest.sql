-- Base sin borrados
WITH src AS (
  SELECT *
  FROM {{ ref('_int__product__general__github_issues_and_problems_union') }}
  WHERE COALESCE(sys_audit_is_deleted, 0) != 1
),

-- Última fila por (repo, issue)
latest AS (
  SELECT
    LOWER(repo_name) AS repo_name,
    issue_number,
    id,
    body,
    labels_name,
    sys_audit_updated_on,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(repo_name), issue_number
      ORDER BY sys_audit_updated_on DESC
    ) AS rn
  FROM src
),

latest_only AS (
  SELECT *
  FROM latest
  WHERE rn = 1
),

-- Labels agregados (concat distinct)
labels_agg AS (
  SELECT
    LOWER(repo_name) AS repo_name,
    issue_number,
    CONCAT_WS(', ', COLLECT_SET(TRIM(COALESCE(labels_name, '')))) AS labels_name
  FROM src
  GROUP BY 1, 2
)

SELECT
  l.repo_name,
  l.issue_number,
  l.id,
  l.body,
  a.labels_name,
  l.sys_audit_updated_on
FROM latest_only l
LEFT JOIN labels_agg a
  ON a.repo_name = l.repo_name
 AND a.issue_number = l.issue_number