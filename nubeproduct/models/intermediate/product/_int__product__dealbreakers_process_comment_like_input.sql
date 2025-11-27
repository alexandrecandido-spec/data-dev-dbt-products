-- _int__product__dealbreakers_process_comment_like_input

-- Paso 1: Listo los dealbreaker_id que tienen is_archived = true como su último estado
WITH deleted AS (
    SELECT
        DISTINCT log.dealbreaker_id as dealbreaker_id
    FROM {{ ref('s__general__dealbreakers_process_changelog__scd') }} log
    WHERE
        log.is_archived = TRUE AND log.is_current = TRUE
),

-- Paso 2: Me traigo la base de registros válidos
base_data AS (
    SELECT
        log.*,
        current.created_by_user_id,
        current.updated_by_user_id
    FROM {{ ref('s__general__dealbreakers_process_changelog__scd') }} log
    LEFT JOIN {{ ref('s__general__hubspot_dealbreaker_current__event') }} current
        ON log.dealbreaker_id = current.dealbreaker_id
    WHERE
        log.dealbreaker_id NOT IN (SELECT dealbreaker_id FROM deleted)
        AND log.is_archived = FALSE
        AND log.repo_name IS NOT NULL
        AND log.issue_number IS NOT NULL
        AND log.store_id IS NOT NULL
        AND log.impact IS NOT NULL
),

-- Paso 3: Excluyo dealbreakers duplicados (distinto dealbreaker_id pero mismo repo_name, issue_number y store_id)
-- me quedo con el más reciente por fecha de processed_at
excluded_duplicated_db AS (
    SELECT *
    FROM (
        SELECT
            b.dealbreaker_id,
            b.repo_name,
            b.issue_number,
            b.store_id,
            ROW_NUMBER() OVER (
                PARTITION BY b.repo_name, b.issue_number, b.store_id
                ORDER BY b.processed_at DESC
            ) AS rn
        FROM base_data b
    ) t
    WHERE rn = 1
),

-- Paso 4: Excluyo versiones anteriores que tiene valores claves distintos al último registro válido
-- me quedo con el más reciente por fecha de processed_at
excluded_key_changes AS (
    SELECT *
    FROM (
        SELECT
            b.dealbreaker_id,
            b.repo_name,
            b.issue_number,
            b.store_id,
            ROW_NUMBER() OVER (
                PARTITION BY b.dealbreaker_id
                ORDER BY b.processed_at DESC
            ) AS rn
        FROM base_data b
    ) t
    WHERE rn = 1
),
    
-- Paso 5: Excluyo versiones anteriores que generan conflicto con la base
deduplicated AS (
SELECT
    b.*
FROM base_data b
INNER JOIN excluded_duplicated_db edd
    ON b.dealbreaker_id = edd.dealbreaker_id
INNER JOIN excluded_key_changes ekc
    ON b.dealbreaker_id = ekc.dealbreaker_id    
    AND b.repo_name = ekc.repo_name
    AND b.issue_number = ekc.issue_number
    AND b.store_id = ekc.store_id
)

SELECT
  d.repo_name,
  d.issue_number,
  'hubspot' as dealbreaker_source,
  d.dealbreaker_id,
  CONCAT('h', COALESCE(d.updated_by_user_id, d.created_by_user_id)) as author,
  TRUE as is_relevant,
  d.valid_from,
  d.store_id,
  CASE
    WHEN d.is_closed = TRUE THEN NULL 
    ELSE d.impact
  END AS impact

FROM deduplicated d
GROUP BY ALL

