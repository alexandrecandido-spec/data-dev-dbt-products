-- _int__product__dealbreakers_process_changelog_input

-- STEP 1: Obtener datos nuevos
WITH current AS (
    SELECT
        dealbreaker_id,
        is_archived,
        repo_name,
        issue_number,
        store_id,
        impact,
        CASE WHEN dealbreaker_close_date IS NULL THEN FALSE ELSE TRUE END AS is_dealbreaker_closed,
        CASE WHEN high_close_date IS NULL THEN FALSE ELSE TRUE END AS is_high_closed
    FROM {{ ref('s__general__hubspot_dealbreaker_current__event') }}
),

deleted AS (
    SELECT
        dealbreaker_id,
        is_archived,
        repo_name,
        issue_number,
        store_id,
        impact,
        CASE WHEN dealbreaker_close_date IS NULL THEN FALSE ELSE TRUE END AS is_dealbreaker_closed,
        CASE WHEN high_close_date IS NULL THEN FALSE ELSE TRUE END AS is_high_closed
    FROM {{ ref('s__general__hubspot_dealbreaker_deleted__event') }}
),

combined_new_data AS (
    SELECT * FROM current
    UNION ALL
    SELECT * FROM deleted
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
        coalesce(impact, ''),
        coalesce(cast(is_dealbreaker_closed AS string), ''),
        coalesce(cast(is_high_closed AS string), '')
      )
    ) AS row_hash
  FROM combined_new_data
)

-- STEP 3: Validar datos
  SELECT
    *,
    CASE
      WHEN is_archived = TRUE THEN TRUE
      WHEN repo_name IS NULL THEN FALSE
      WHEN lower(repo_name) NOT IN ('issues', 'problems') THEN FALSE
      WHEN issue_number IS NULL OR issue_number NOT RLIKE '^[0-9]+$' THEN FALSE
      WHEN store_id IS NULL OR store_id NOT RLIKE '^[0-9]+$' THEN FALSE
      WHEN impact IS NULL OR lower(impact) NOT IN ('high', 'dealbreaker') THEN FALSE
      ELSE TRUE
    END AS is_valid,

    CASE
      WHEN is_archived = TRUE THEN NULL
      WHEN repo_name IS NULL THEN 'repo_name is NULL'
      WHEN lower(repo_name) NOT IN ('issues', 'problems') THEN 'repo_name not in (issues, problems)'
      WHEN issue_number IS NULL OR issue_number NOT RLIKE '^[0-9]+$' THEN 'issue_number is NULL or not numeric'
      WHEN store_id IS NULL OR store_id NOT RLIKE '^[0-9]+$' THEN 'store_id is NULL or not numeric'
      WHEN impact IS NULL THEN 'impact is NULL'
      WHEN lower(impact) NOT IN ('high', 'dealbreaker') THEN 'impact not in (high, dealbreaker)'
      ELSE NULL
    END AS invalid_reason
  FROM new_data_hashed