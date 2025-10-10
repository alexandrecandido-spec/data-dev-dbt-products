{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  partition_by='year_month_day_code',
  unique_key=['full_url', 'date', 'search_type', 'country_name', 'device'],
  on_schema_change='fail',
  tags=['daily-9am']
) }}

WITH union_gsc_results AS (
  SELECT * FROM {{ ref('_int__gsc_results_aggregated') }}
  UNION ALL
  SELECT * FROM {{ ref('_int__gsc_results_diff') }}
),
existing_data AS (
  {{ get_existing_data(this, ['full_url', 'date', 'search_type', 'country_name', 'device', 'sys_audit_created_on', 'sys_audit_created_by', 'year_month_day_code']) }}
)

SELECT 
  u.*,

  CASE
    WHEN instr(u.full_url, '/blog') > 0 THEN 'Blog'
    WHEN instr(u.full_url, '/banners') > 0
      OR instr(u.full_url, '/e-books') > 0
      OR instr(u.full_url, '/ebooks') > 0
      OR instr(u.full_url, '/recursos') > 0
      OR instr(u.full_url, '/materiais') > 0
      OR instr(u.full_url, 'materiais.nuvemshop.com.br') > 0
      OR instr(u.full_url, 'recursos.tiendanube.com') > 0
      THEN 'Downloadables'
    WHEN instr(u.full_url, '/ferramentas') > 0
      OR instr(u.full_url, '/herramientas') > 0
      OR instr(u.full_url, 'creadordebanners.com') > 0
      OR instr(u.full_url, 'creadordelogos.com.ar') > 0
      OR instr(u.full_url, 'creadordelogos.com.mx') > 0
      OR instr(u.full_url, 'criadordebanner.com') > 0
      OR instr(u.full_url, 'criadordelogo.com.br') > 0
      OR instr(u.full_url, 'fornecedoresdropshipping.com') > 0
      OR instr(u.full_url, 'nuv.link') > 0
      OR instr(u.full_url, 'paletadecolores.com.ar') > 0
      OR instr(u.full_url, 'paletadecolores.com.mx') > 0
      OR instr(u.full_url, 'paletadecores.com') > 0
      THEN 'Tools'
    WHEN instr(u.full_url, 'trilhas.nuvemshop.com.br') > 0
      OR instr(u.full_url, '/trilhas') > 0
      OR instr(u.full_url, '/cursos-ecommerce') > 0
      OR instr(u.full_url, '/ecommerce-por-expertos') > 0
      OR instr(u.full_url, '/universidade') > 0
      THEN 'Trilhas'
    WHEN instr(u.full_url, '/universidad') > 0 THEN 'Universidad'
    ELSE 'Otros'
  END AS subteam,

  CASE
    WHEN instr(u.full_url, 'nuvemshop') > 0
      OR instr(u.full_url, '.br') > 0
      OR instr(u.full_url, 'fornecedoresdropshipping.com') > 0
      OR instr(u.full_url, 'nuv.link') > 0
      THEN 'BR'
    ELSE
      CASE
        WHEN u.date <= DATE '2024-09-07' THEN
          CASE
            WHEN instr(u.full_url, '/mx/') > 0 THEN 'MX'
            WHEN instr(u.full_url, '/co/') > 0 THEN 'CO'
            WHEN instr(u.full_url, '/cl/') > 0 THEN 'CL'
            ELSE 'AR'
          END
        ELSE
          CASE
            WHEN u.country_name LIKE '%Mexico%' THEN 'MX'
            WHEN u.country_name LIKE '%Colombia%' THEN 'CO'
            WHEN u.country_name LIKE '%Chile%' THEN 'CL'
            WHEN u.country_name LIKE '%Argentina%' THEN 'AR'
            ELSE 'Otros'
          END
      END
  END AS classified_country,

  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by,

  CAST(date_format(u.date, 'yyyyMMdd') AS INT) AS year_month_day_code

FROM union_gsc_results u
LEFT JOIN {{ ref('_int__route_patterns') }} rp ON instr(u.full_url, rp.pattern) > 0
LEFT JOIN {{ ref('_int__domain_patterns') }} dp ON startswith(u.full_url, 'https://www.' || dp.domain)
                              OR startswith(u.full_url, 'https://' || dp.domain)

LEFT JOIN existing_data e ON 
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
