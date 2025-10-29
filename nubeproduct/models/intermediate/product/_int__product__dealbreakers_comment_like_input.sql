
WITH deduplicated AS (
  SELECT *
  FROM {{ ref('_int__product__dealbreakers_comment_like_pre_input') }}
),

-- Paso 6: Separo los impact = dealbreaker que están cerrados
closed_dealbreakers AS (
  SELECT
    d.repo_name,
    d.issue_number,
    'hubspot' as dealbreaker_source,
    d.dealbreaker_id,
    CONCAT('h', COALESCE(d.updated_by_user_id, d.created_by_user_id)) as author,
    TRUE as is_relevant,
    d.valid_from,
    d.store_id,
    NULL as impact

  FROM deduplicated d
  WHERE
    d.impact = 'dealbreaker' AND d.dealbreaker_close_date IS NOT NULL
  GROUP BY ALL
),

-- Paso 7: Separo los impact = high que están cerrados
closed_high AS (
  SELECT
    d.repo_name,
    d.issue_number,
    'hubspot' as dealbreaker_source,
    d.dealbreaker_id,
    CONCAT('h', COALESCE(d.updated_by_user_id, d.created_by_user_id)) as author,
    TRUE as is_relevant,
    d.valid_from,
    d.store_id,
    NULL as impact

  FROM deduplicated d
  WHERE
    d.impact = 'high' AND d.high_close_date IS NOT NULL
  GROUP BY ALL
),

-- Paso 8: Separo los registros que están abiertos
open_records AS (
  SELECT
    d.repo_name,
    d.issue_number,
    'hubspot' as dealbreaker_source,
    d.dealbreaker_id,
    CONCAT('h', COALESCE(d.updated_by_user_id, d.created_by_user_id)) as author,
    TRUE as is_relevant,
    d.valid_from,
    d.store_id,
    d.impact

  FROM deduplicated d
  WHERE
    CASE WHEN d.impact = 'dealbreaker' AND d.dealbreaker_close_date IS NOT NULL THEN TRUE ELSE FALSE END = FALSE
    AND CASE WHEN d.impact = 'high' AND d.high_close_date IS NOT NULL THEN TRUE ELSE FALSE END = FALSE
  GROUP BY ALL
)

SELECT * FROM closed_dealbreakers
UNION ALL
SELECT * FROM closed_high
UNION ALL
SELECT * FROM open_records