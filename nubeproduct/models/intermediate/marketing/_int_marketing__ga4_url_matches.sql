
SELECT
  landing_page_domain,
  landing_page_path,
  team,
  subteam
FROM {{ ref('marketing_inputs_attribution__url') }}

UNION ALL

SELECT
  landing_page_domain,
  landing_page_path,
  team,
  subteam
FROM {{ ref('marketing_inputs_attribution__insti') }}
