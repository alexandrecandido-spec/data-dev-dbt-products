{{ config(
  materialized = 'incremental',
  incremental_strategy = 'merge',
  unique_key = ['dealbreaker_id', 'valid_from'],
  on_schema_change = 'fail',
  tags = ['daily-9am']
) }}

-- s__general__dealbreakers_process_changelog__scd

WITH base AS (
  SELECT
    dealbreaker_id,
    processed_at,
    is_archived,
    repo_name,
    issue_number,
    store_id,
    impact,
    is_dealbreaker_closed,
    is_high_closed,
    valid_from,
    is_valid,
    invalid_reason,
    sys_audit_created_on,
    sys_audit_created_by,
    sys_audit_updated_on,
    sys_audit_updated_by
  FROM {{ ref('s__general__dealbreakers_process_changelog_input__scd') }}
),

-- STEP 1: Deduplicar versiones repetidas por día de processed_at
deduplicated AS (
  SELECT *
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY dealbreaker_id, valid_from
        ORDER BY processed_at DESC
      ) AS rn
    FROM base
  ) t
  WHERE rn = 1
),

-- STEP 2: Ordenar por id y fecha de inicio
ordered AS (
  SELECT *,
    LEAD(valid_from) OVER (
      PARTITION BY dealbreaker_id
      ORDER BY valid_from
    ) AS next_valid_from,

    MAX(valid_from) OVER (
      PARTITION BY dealbreaker_id
    ) AS latest_valid_from
  FROM deduplicated
)

-- STEP 3: Calcular valid_to e is_current
  SELECT
    dealbreaker_id,
    processed_at,
    is_archived,
    repo_name,
    issue_number,
    store_id,
    impact,
    is_dealbreaker_closed,
    is_high_closed,
    valid_from,

    CASE
      WHEN next_valid_from IS NULL THEN DATE('9999-12-31')
      ELSE DATE_SUB(next_valid_from, 1)
    END AS valid_to,

    CASE
      WHEN valid_from = latest_valid_from THEN TRUE
      ELSE FALSE
    END AS is_current,

    is_valid,
    invalid_reason,
    sys_audit_created_on,
    sys_audit_created_by,
    sys_audit_updated_on,
    sys_audit_updated_by
  FROM ordered
