-- s__general__dealbreakers_process_comment_like__event

{{ config(
  materialized = 'table',
  unique_key = ['comment_id'],
  on_schema_change = 'fail',
  tags = ['daily-9am']
) }}

SELECT
    repo_name,
    issue_number,
    CAST(
    CONCAT(
      DATE_FORMAT(valid_from, 'yyyyMMdd'),
      CAST(dealbreaker_id AS STRING)
        ) AS BIGINT
    ) AS comment_id,
    author,
    is_relevant,
    valid_from as comment_date,
    store_id,
    impact,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('s__general__dealbreakers_process_valid__event') }}