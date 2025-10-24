-- STEP 1: Obtener datos nuevos
WITH current AS (
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
        high_close_date
    FROM {{ ref('s__general__hubspot_dealbreaker_current__event') }}
),

deleted AS (
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
        high_close_date
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
        coalesce(cast(company_id AS string), ''),
        coalesce(impact, ''),
        coalesce(cast(dealbreaker_start_date AS string), ''),
        coalesce(cast(dealbreaker_close_date AS string), ''),
        coalesce(cast(high_start_date AS string), ''),
        coalesce(cast(high_close_date AS string), '')
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
      WHEN company_id IS NULL OR company_id NOT RLIKE '^[0-9]+$' THEN FALSE
      WHEN impact IS NULL OR lower(impact) NOT IN ('high', 'dealbreaker') THEN FALSE
      WHEN lower(impact) = 'high' AND high_start_date IS NULL THEN FALSE
      WHEN lower(impact) = 'dealbreaker' AND dealbreaker_start_date IS NULL THEN FALSE
      WHEN lower(impact) = 'high' AND dealbreaker_start_date IS NOT NULL AND high_start_date < dealbreaker_start_date THEN FALSE
      WHEN lower(impact) = 'dealbreaker' AND high_start_date IS NOT NULL AND dealbreaker_start_date < high_start_date THEN FALSE
      WHEN lower(impact) = 'high' AND dealbreaker_start_date IS NOT NULL AND 
           (dealbreaker_close_date IS NULL OR dealbreaker_close_date > high_start_date) THEN FALSE
      WHEN lower(impact) = 'dealbreaker' AND high_start_date IS NOT NULL AND 
           (high_close_date IS NULL OR high_close_date > dealbreaker_start_date) THEN FALSE
      WHEN dealbreaker_close_date IS NOT NULL AND dealbreaker_start_date IS NOT NULL 
           AND dealbreaker_close_date < dealbreaker_start_date THEN FALSE
      WHEN high_close_date IS NOT NULL AND high_start_date IS NOT NULL 
           AND high_close_date < high_start_date THEN FALSE
      WHEN high_start_date > current_date OR high_close_date > current_date
           OR dealbreaker_start_date > current_date OR dealbreaker_close_date > current_date THEN FALSE
      ELSE TRUE
    END AS is_valid,

    CASE
      WHEN is_archived = TRUE THEN NULL
      WHEN repo_name IS NULL THEN 'repo_name is NULL'
      WHEN lower(repo_name) NOT IN ('issues', 'problems') THEN 'repo_name not in (issues, problems)'
      WHEN issue_number IS NULL OR issue_number NOT RLIKE '^[0-9]+$' THEN 'issue_number is NULL or not numeric'
      WHEN store_id IS NULL OR store_id NOT RLIKE '^[0-9]+$' THEN 'store_id is NULL or not numeric'
      WHEN company_id IS NULL OR company_id NOT RLIKE '^[0-9]+$' THEN 'company_id is NULL or not numeric'
      WHEN impact IS NULL THEN 'impact is NULL'
      WHEN lower(impact) NOT IN ('high', 'dealbreaker') THEN 'impact not in (high, dealbreaker)'
      WHEN lower(impact) = 'high' AND high_start_date IS NULL THEN 'impact is high and high_start_date is NULL'
      WHEN lower(impact) = 'dealbreaker' AND dealbreaker_start_date IS NULL THEN 'impact is dealbreaker and dealbreaker_start_date is NULL'
      WHEN lower(impact) = 'high' AND dealbreaker_start_date IS NOT NULL AND high_start_date < dealbreaker_start_date THEN 'impact is high and high_start_date < dealbreaker_start_date'
      WHEN lower(impact) = 'dealbreaker' AND high_start_date IS NOT NULL AND dealbreaker_start_date < high_start_date THEN 'impact is dealbreaker and dealbreaker_start_date < high_start_date'
      WHEN lower(impact) = 'high' AND dealbreaker_start_date IS NOT NULL AND 
           (dealbreaker_close_date IS NULL OR dealbreaker_close_date > high_start_date) THEN 'dealbreaker_close_date invalid for high impact'
      WHEN lower(impact) = 'dealbreaker' AND high_start_date IS NOT NULL AND 
           (high_close_date IS NULL OR high_close_date > dealbreaker_start_date) THEN 'high_close_date invalid for dealbreaker impact'
      WHEN dealbreaker_close_date IS NOT NULL AND dealbreaker_start_date IS NOT NULL 
           AND dealbreaker_close_date < dealbreaker_start_date THEN 'dealbreaker_close_date < dealbreaker_start_date'
      WHEN high_close_date IS NOT NULL AND high_start_date IS NOT NULL 
           AND high_close_date < high_start_date THEN 'high_close_date < high_start_date'
      WHEN high_start_date > current_date OR high_close_date > current_date
           OR dealbreaker_start_date > current_date OR dealbreaker_close_date > current_date THEN 'future dates'
      ELSE NULL
    END AS invalid_reason
  FROM new_data_hashed