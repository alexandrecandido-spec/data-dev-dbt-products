WITH base AS (
  SELECT * FROM {{ ref('_int__product__general__issues_summary_data_base_latest') }}
),

-- Solo el bloque RICE (desde "RICE" hasta "Updates" o fin)
rice_block AS (
  SELECT
    repo_name,
    issue_number,
    id,
    body,
    labels_name,
    REGEXP_EXTRACT(
      body,
      '(?is)\\bRICE\\b.*?(?:\\r?\\n)(.*?)(?:\\r?\\n\\s*Updates\\b|\\z)',
      1
    ) AS rice_section
  FROM base
),

-- Extrae números en la MISMA línea de Impacto/Confianza/Esforço dentro del bloque RICE
rice_raw AS (
  SELECT
    repo_name,
    issue_number,
    id,
    body,
    labels_name,

    CAST(
      NULLIF(
        REPLACE(
          REGEXP_EXTRACT(
            COALESCE(rice_section, ''),
            '(?im)impacto\\s*:\\s*[^0-9\\r\\n]{0,10}([0-9]+(?:[\\.,][0-9]+)?)\\b',
            1
          ),
          ',', '.'
        ),
        ''
      ) AS DOUBLE
    ) AS impact_raw,

    CAST(
      NULLIF(
        REPLACE(
          REGEXP_EXTRACT(
            COALESCE(rice_section, ''),
            '(?im)(?:confianza|confianca|confiança)\\s*:\\s*[^0-9\\r\\n]{0,10}([0-9]+(?:[\\.,][0-9]+)?)\\b',
            1
          ),
          ',', '.'
        ),
        ''
      ) AS DOUBLE
    ) AS confidence_raw,

    CAST(
      NULLIF(
        REPLACE(
          REGEXP_EXTRACT(
            COALESCE(rice_section, ''),
            '(?im)(?:esfuerzo|esforco|esforço)\\s*:\\s*[^0-9\\r\\n]{0,10}([0-9]+(?:[\\.,][0-9]+)?)\\b',
            1
          ),
          ',', '.'
        ),
        ''
      ) AS DOUBLE
    ) AS effort_raw
  FROM rice_block
)

SELECT
  b.repo_name,
  b.issue_number,
  b.id,
  b.body,
  b.labels_name,

  COALESCE(r.impact_raw, 0.0) AS impact,

  CASE
    WHEN r.confidence_raw IS NULL THEN 0.0
    WHEN r.confidence_raw > 0 AND r.confidence_raw <= 1 THEN r.confidence_raw * 100
    ELSE r.confidence_raw
  END AS confidence,

  COALESCE(r.effort_raw, 0.0) AS effort
FROM rice_raw r
JOIN base b
  ON b.repo_name = r.repo_name
 AND b.issue_number = r.issue_number
 AND b.id = r.id