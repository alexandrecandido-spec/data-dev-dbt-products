{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['dealbreaker_id', 'valid_from', 'row_hash'],
    on_schema_change = 'fail',
    tags = ['daily-9am']
) }}

-- s__general__dealbreakers_process_changelog_input__scd

-- STEP 1: Obtener datos nuevos
-- STEP 2: Hash de fila para comparar cambios
-- STEP 3: Validar datos
WITH validated_data AS (
  SELECT * FROM {{ ref('_int__product__dealbreakers_process_changelog_input') }}
),

-- STEP 4: Obtener versión actual de la tabla histórica
{% if is_incremental() %}

  existing_current AS (

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
      sys_audit_updated_by,
      row_hash
    FROM (

      SELECT *,
        ROW_NUMBER() OVER (
          PARTITION BY dealbreaker_id
          ORDER BY processed_at DESC
        ) AS rn
      FROM {{ this }}

    ) latest
    WHERE rn = 1

  )

{% else %}

  existing_current AS (
    SELECT
      CAST(NULL AS STRING) AS dealbreaker_id,
      CAST(NULL AS TIMESTAMP) AS processed_at,
      CAST(NULL AS BOOLEAN) AS is_archived,
      CAST(NULL AS STRING) AS repo_name,
      CAST(NULL AS INT) AS issue_number,
      CAST(NULL AS STRING) AS store_id,
      CAST(NULL AS STRING) AS impact,
      CAST(NULL AS BOOLEAN) AS is_dealbreaker_closed,
      CAST(NULL AS BOOLEAN) AS is_high_closed,
      CAST(NULL AS DATE) AS valid_from,
      CAST(NULL AS BOOLEAN) AS is_valid,
      CAST(NULL AS STRING) AS invalid_reason,
      CAST(NULL AS TIMESTAMP) AS sys_audit_created_on,
      CAST(NULL AS STRING) AS sys_audit_created_by,
      CAST(NULL AS TIMESTAMP) AS sys_audit_updated_on,
      CAST(NULL AS STRING) AS sys_audit_updated_by,
      CAST(NULL AS STRING) AS row_hash
    WHERE FALSE
  )

{% endif %}

  SELECT
    v.dealbreaker_id,
    current_timestamp AS processed_at,
    v.is_archived,
    v.repo_name,
    v.issue_number,
    v.store_id,
    v.impact,
    v.is_dealbreaker_closed,
    v.is_high_closed,
    CAST(DATE_SUB(current_date, 1) AS DATE) AS valid_from,
    v.is_valid,
    v.invalid_reason,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    v.row_hash   
  FROM validated_data v
  LEFT JOIN existing_current e
    ON v.dealbreaker_id = e.dealbreaker_id
  WHERE e.row_hash IS NULL OR v.row_hash <> e.row_hash
