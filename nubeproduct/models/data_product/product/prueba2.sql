
{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['dealbreaker_id', 'valid_from'],
    on_schema_change = 'fail',
    tags = ['daily-9am']
) }}

    WITH combined_new_data AS (
    SELECT
        dealbreaker_id,
        is_archived,
        repo_name,
        issue_number,
        store_id,
        company_id,
        impact,
        dealbreaker_start_date,
        dealbreaker_close_date,
        high_start_date,
        high_close_date,
        date_add(current_date, 8) AS snapshot_date
    FROM {{ ref('prueba') }}
),

-- STEP 2: Hash de fila para comparar cambios
new_data_hashed AS (
  SELECT *,
    md5(
      concat_ws('||',
        coalesce(cast(is_archived AS string), ''),
        coalesce(repo_name, ''),
        coalesce(cast(issue_number AS string), ''),
        coalesce(cast(store_id AS string), ''),
        coalesce(cast(company_id AS string), ''),
        coalesce(impact, ''),
        coalesce(cast(dealbreaker_start_date AS string), ''),
        coalesce(cast(dealbreaker_close_date AS string), ''),
        coalesce(cast(high_start_date AS string), ''),
        coalesce(cast(high_close_date AS string), '')
      )
    ) AS row_hash
  FROM combined_new_data
),

-- STEP 3: Obtener versión actual de la tabla histórica
{% if is_incremental() %}
  existing_current AS (
    SELECT
      dealbreaker_id,
      is_archived,
      repo_name,
      issue_number,
      store_id,
      company_id,
      impact,
      dealbreaker_start_date,
      dealbreaker_close_date,
      high_start_date,
      high_close_date,
      valid_from,
      valid_to,
      is_current,
      is_valid,
      sys_audit_created_on,
      sys_audit_created_by,
      sys_audit_updated_on,
      sys_audit_updated_by,
      row_hash
    FROM {{ this }}
    WHERE is_current = TRUE
  ),
{% else %}
  existing_current AS (
    SELECT
      CAST(NULL AS STRING) AS dealbreaker_id,
      CAST(NULL AS BOOLEAN) AS is_archived,
      CAST(NULL AS STRING) AS repo_name,
      CAST(NULL AS INT) AS issue_number,
      CAST(NULL AS STRING) AS store_id,
      CAST(NULL AS STRING) AS company_id,
      CAST(NULL AS STRING) AS impact,
      CAST(NULL AS DATE) AS dealbreaker_start_date,
      CAST(NULL AS DATE) AS dealbreaker_close_date,
      CAST(NULL AS DATE) AS high_start_date,
      CAST(NULL AS DATE) AS high_close_date,
      CAST(NULL AS DATE) AS valid_from,
      CAST(NULL AS DATE) AS valid_to,
      CAST(NULL AS BOOLEAN) AS is_current,
      CAST(NULL AS BOOLEAN) AS is_valid,
      CAST(NULL AS TIMESTAMP) AS sys_audit_created_on,
      CAST(NULL AS STRING) AS sys_audit_created_by,
      CAST(NULL AS TIMESTAMP) AS sys_audit_updated_on,
      CAST(NULL AS STRING) AS sys_audit_updated_by,
      CAST(NULL AS STRING) AS row_hash
    WHERE FALSE
  ),
{% endif %}

-- STEP 4: Detectar cambios y preparar nuevas versiones
new_versions AS (
  SELECT
    n.dealbreaker_id,
    n.is_archived,
    n.repo_name,
    n.issue_number,
    n.store_id,
    n.company_id,
    n.impact,
    n.dealbreaker_start_date,
    n.dealbreaker_close_date,
    n.high_start_date,
    n.high_close_date,
    date_add(current_date, 8) AS valid_from,
    DATE('9999-12-31') AS valid_to,
    TRUE AS is_current,
    TRUE AS is_valid,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    n.row_hash   
  FROM new_data_hashed n
  LEFT JOIN existing_current e
    ON n.dealbreaker_id = e.dealbreaker_id
  WHERE e.row_hash IS NULL OR n.row_hash <> e.row_hash
),

-- STEP 5: Cerrar versiones anteriores
closed_versions AS (
  SELECT
    e.dealbreaker_id,
    e.is_archived,
    e.repo_name,
    e.issue_number,
    e.store_id,
    e.company_id,
    e.impact,
    e.dealbreaker_start_date,
    e.dealbreaker_close_date,
    e.high_start_date,
    e.high_close_date,
    e.valid_from,
    DATE_SUB(current_date, 1) AS valid_to,
    FALSE AS is_current,
    e.is_valid,
    e.sys_audit_created_on,
    e.sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    e.row_hash
  FROM existing_current e
  INNER JOIN new_data_hashed n
    ON e.dealbreaker_id = n.dealbreaker_id
  WHERE e.row_hash <> n.row_hash
)

-- STEP 6: Unión final
SELECT * FROM new_versions
UNION ALL
SELECT * FROM closed_versions