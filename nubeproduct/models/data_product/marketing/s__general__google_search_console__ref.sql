{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  partition_by='year_month_day_code',
  unique_key=['full_url', 'date', 'search_type', 'country_name', 'device'],
  on_schema_change='fail',
  tags=['marketing']
) }}

WITH union_gsc_results AS (
  SELECT * FROM {{ ref('_int__gsc_results_aggregated') }} -- Materialized table with all GSC results aggregated by date, full_url, path, search_type, country_name, device
  UNION ALL
  SELECT * FROM {{ ref('_int__gsc_results_diff') }} -- Materialized table with all GSC results diff by date, full_url, path, search_type, country_name, device

),

existing_data AS (
  {{ get_existing_data(this, ['full_url', 'date', 'search_type', 'country_name', 'device', 'sys_audit_created_on', 'sys_audit_created_by', 'year_month_day_code']) }}
)

SELECT 
  u.*,

  {{ classify_subteam_from_url('u.full_url') }} AS subteam, -- Macro to classify the subteam from the full_url
  {{ classify_country('u.full_url', 'u.date', 'u.country_name') }} AS classified_country, -- Macro to classify the country from the full_url and date


  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by,

  CAST(date_format(u.date, 'yyyyMMdd') AS INT) AS year_month_day_code

FROM union_gsc_results u
LEFT JOIN {{ ref('_int__route_patterns') }} rp ON instr(u.full_url, rp.pattern) > 0 -- Materialized table with all route patterns
LEFT JOIN {{ ref('_int__domain_patterns') }} dp ON startswith(u.full_url, 'https://www.' || dp.domain) OR startswith(u.full_url, 'https://' || dp.domain) -- Materialized table with all domain patterns
LEFT JOIN existing_data e ON -- Materialized table with all existing data
  u.full_url = e.full_url AND
  u.date = e.date AND
  u.search_type = e.search_type AND
  u.country_name = e.country_name AND
  u.device = e.device AND
  CAST(date_format(u.date, 'yyyyMMdd') AS INT) = e.year_month_day_code
  
WHERE rp.pattern IS NOT NULL OR dp.domain IS NOT NULL
{% if is_incremental() %} 
  AND u.sys_audit_updated_on > (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '2000-01-01') FROM {{ this }})
{% endif %}
