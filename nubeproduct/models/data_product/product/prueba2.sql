{{ config(
   materialized = 'incremental',
   incremental_strategy = 'merge',
   unique_key = ['dealbreaker_id', 'valid_from', 'row_hash'],
   on_schema_change = 'fail',
   tags = ['daily-9am']
) }}


{% set run_date = var("run_date", none) %}
{% if run_date is none %}
 {% set run_date = modules.datetime.date.today().isoformat() %}
{% endif %}


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
       high_close_date
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


-- STEP 3: Validar datos
validated_data AS (
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
     WHEN high_start_date > DATE('{{ run_date }}') OR high_close_date > DATE('{{ run_date }}')
          OR dealbreaker_start_date > DATE('{{ run_date }}') OR dealbreaker_close_date > DATE('{{ run_date }}') THEN FALSE
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
     WHEN high_start_date > DATE('{{ run_date }}') OR high_close_date > DATE('{{ run_date }}')
          OR dealbreaker_start_date > DATE('{{ run_date }}') OR dealbreaker_close_date > DATE('{{ run_date }}') THEN 'future dates'
     ELSE NULL
   END AS invalid_reason
 FROM new_data_hashed
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
     company_id,
     impact,
     dealbreaker_start_date,
     dealbreaker_close_date,
     high_start_date,
     high_close_date,
     valid_from,
     valid_to,
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
     CAST(NULL AS STRING) AS company_id,
     CAST(NULL AS STRING) AS impact,
     CAST(NULL AS DATE) AS dealbreaker_start_date,
     CAST(NULL AS DATE) AS dealbreaker_close_date,
     CAST(NULL AS DATE) AS high_start_date,
     CAST(NULL AS DATE) AS high_close_date,
     CAST(NULL AS DATE) AS valid_from,
     CAST(NULL AS DATE) AS valid_to,
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
   TIMESTAMP('{{ run_date }}') AS processed_at,
   v.is_archived,
   v.repo_name,
   v.issue_number,
   v.store_id,
   v.company_id,
   v.impact,
   v.dealbreaker_start_date,
   v.dealbreaker_close_date,
   v.high_start_date,
   v.high_close_date,
   CAST(DATE_SUB(DATE('{{ run_date }}'), 1) AS DATE) AS valid_from,
   DATE('9999-12-31') AS valid_to,
   v.is_valid,
   v.invalid_reason,
   TIMESTAMP('{{ run_date }}') AS sys_audit_created_on,
   'data-dev-dbt-products' AS sys_audit_created_by,
   TIMESTAMP('{{ run_date }}') AS sys_audit_updated_on,
   'data-dev-dbt-products' AS sys_audit_updated_by,
   v.row_hash  
 FROM validated_data v
 LEFT JOIN existing_current e
   ON v.dealbreaker_id = e.dealbreaker_id
 WHERE e.row_hash IS NULL OR v.row_hash <> e.row_hash