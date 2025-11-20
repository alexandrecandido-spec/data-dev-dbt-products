{{
  config(
    materialized='table',
    tags=['daily-9am']
  )
}}

-- =============================================================================
-- Google Keyword Planner Enriched Model (Silver Layer)
-- =============================================================================
-- NOTE: Currently uses manual data upload process via data_manual.ext__ table
--       until API integration is implemented by Engineering team
-- Source: Uses _int_marketing_google_keyword_planner_clean (intermediate layer)
-- =============================================================================

WITH base_data AS (
  SELECT * 
  FROM {{ ref('_int_marketing_google_keyword_planner_clean') }}
),

brand_detection AS (
  SELECT *,
    -- D2C Brand Detection (same logic as Search Console)
    {{ get_d2c_brand_detection('country', 'search_query') }} AS d2c_detected,
    
    -- Marketplace Brand Detection  
    {{ get_marketplace_brand_detection('country', 'search_query') }} AS marketplace_detected,
    
    -- Tiendanube/Nuvemshop Detection (our brands)
    CASE 
      WHEN LOWER(search_query) RLIKE '.*(tienda\\s*nube|nuvem\\s*shop).*' THEN TRUE
      ELSE FALSE
    END AS is_nuvemshop_tiendanube,
    
    -- Next/Evolution Detection (product roadmap intelligence)
    CASE 
      WHEN LOWER(search_query) RLIKE '.*(tienda\\s*nube|nuvem\\s*shop).*(next|evoluci[oó]n).*'
        OR LOWER(search_query) RLIKE '.*(next|evoluci[oó]n).*(tienda\\s*nube|nuvem\\s*shop).*'
      THEN TRUE
      ELSE FALSE  
    END AS is_next_evolucion
    
  FROM base_data
),

kwp_classification AS (
  SELECT *,
    -- KWP Category Classification using business-specific macro
    {{ get_kwp_category_mapping('search_query', 'country') }} AS kwp_category
    
  FROM brand_detection
),

official_flags AS (
  SELECT *,
    -- Official D2C Flag (false if is_next_evolucion = true)
    CASE 
      WHEN is_next_evolucion = true THEN false
      WHEN d2c_detected.brand_name IS NOT NULL 
        AND d2c_detected.brand_name IN ('tiendanube', 'nuvemshop', 'nuvem shop', 'tienda nube')
      THEN true
      ELSE false
    END AS flag_d2c_oficial,
    
    -- Official Marketplace Flag (false if is_next_evolucion = true)
    CASE 
      WHEN is_next_evolucion = true THEN false  
      WHEN marketplace_detected.brand_name IS NOT NULL
        AND marketplace_detected.brand_name IN ('tiendanube', 'nuvemshop', 'nuvem shop', 'tienda nube')
      THEN true
      ELSE false
    END AS flag_marketplace_oficial
    
  FROM kwp_classification
),

enriched_data AS (
  SELECT *,
    -- Add date dimensions
    {{ get_date_dimensions('date') }} AS date_dimensions
    
  FROM official_flags
)

SELECT
  -- Core date dimensions  
  date,
  date_dimensions.month AS date_month,
  date_dimensions.quarter AS date_quarter,
  date_dimensions.year AS date_year,
  
  -- Geography
  country,
  
  -- Search Core
  search_query,
  kwp_category,
  
  -- Brand Detection Results
  d2c_detected.brand_name AS d2c_brand_names,
  marketplace_detected.brand_name AS marketplace_brand_names,
  
  -- Brand Monitoring Flags
  is_nuvemshop_tiendanube,
  is_next_evolucion,
  
  -- Official Brand Flags
  flag_d2c_oficial,
  flag_marketplace_oficial,
  
  -- Metrics
  impressions,
  
  -- Audit fields
  sys_audit_created_on,
  sys_audit_updated_on

FROM enriched_data