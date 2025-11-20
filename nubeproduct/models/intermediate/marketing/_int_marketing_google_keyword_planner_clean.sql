-- Intermediate models are ephemeral by default (no config needed)

-- =============================================================================
-- Google Keyword Planner Intermediate - Clean Data
-- =============================================================================
-- Purpose: Clean and normalize raw KWP data from manual upload process
-- Responsibilities: 
--   - Column renaming and type conversion
--   - Date format conversion (M/d/yyyy string → DATE)
--   - Basic data quality filters  
--   - Historical data filtering (>= 2020-01-01)
-- Next Layer: s__brand_and_comms__keyword_planner_enriched__event (brand detection + classification)
-- =============================================================================

WITH base_data AS (
  SELECT 
    -- Column renaming for consistency
    keyword AS search_query,
    country,
    
    -- Convert string date from M/d/yyyy format (month/day/year) to proper DATE
    -- KWP data is MONTHLY - typically first day of month represents the whole month
    CASE 
      WHEN date RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 
        TO_DATE(date, 'M/d/yyyy')
      ELSE NULL
    END AS date,
    
    -- Type conversion and validation
    CAST(searches AS BIGINT) AS impressions,
    
    -- Audit fields from source
    CURRENT_TIMESTAMP() AS sys_audit_created_on,
    CURRENT_TIMESTAMP() AS sys_audit_updated_on
    
  FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
  
  -- Basic data quality filters
  WHERE searches IS NOT NULL 
    AND country IS NOT NULL
    AND keyword IS NOT NULL
    AND date IS NOT NULL
    AND CAST(searches AS BIGINT) >= 0  -- No negative search volumes
),

validated_data AS (
  SELECT *
  FROM base_data
  WHERE date IS NOT NULL  -- Ensure date conversion was successful
    AND date >= DATE('2020-01-01')  -- Historical data filter
    AND impressions > 0  -- Only meaningful search volumes
)

SELECT 
  search_query,
  country, 
  date,
  impressions,
  sys_audit_created_on,
  sys_audit_updated_on
FROM validated_data
