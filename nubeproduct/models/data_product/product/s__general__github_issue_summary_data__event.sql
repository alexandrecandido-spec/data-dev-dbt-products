{{ tier_by_prefix() }}
{{
  config(
    tags=['daily-9am'],
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['issue_number','repo_name'],
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

WITH features AS (
  SELECT * FROM {{ ref('_int__product__general__issues_summary_data_features') }}
),
existing_data AS (
  {{ get_existing_data(this, ['issue_number','repo_name','sys_audit_created_on','sys_audit_created_by']) }}
),
final AS (
  SELECT
    f.id,
    f.repo_name,
    f.issue_number,
    f.issue_type,
    f.impact,
    f.confidence,
    f.effort,
    f.has_steps,
    f.has_logs,
    f.has_quickfix,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
  FROM features f
  LEFT JOIN existing_data e
    ON f.repo_name = e.repo_name
   AND f.issue_number = e.issue_number
)

SELECT *
FROM final
{% if is_incremental() %}
WHERE sys_audit_updated_on > (
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01 00:00:00') - INTERVAL '24 hours'
  FROM {{ this }}
)
{% endif %}
