{{
  config(
    materialized='table'
  )
}}

-- =============================================================================
-- Marketing Goals KWP & Search Console Intermediate - Clean Data
-- =============================================================================
-- Purpose: Clean and normalize raw brand/nonbrand goals for KWP and Search Console
-- Responsibilities:
--   - Column renaming and type conversion for SC/KWP specific goals
--   - Country standardization  
--   - Basic data quality filters for brand/nonbrand targets
--   - Date range filtering (2025+ goals)
-- Next Layer: s__goals__targets_kwp_sc (date dimensions + metadata)
-- =============================================================================

WITH base_goals AS (
  SELECT 
    -- Date is already in proper DATE format from source
    date,
    
    -- Standardize country names (uppercase and trim)
    UPPER(TRIM(country)) AS country,
    
    -- Column renaming and type conversion for goal metrics
    CAST(expected_impressions_brand_exact_sc_daily AS DOUBLE) AS expected_branded_sc,
    CAST(expected_market_share_brand_kwp AS DOUBLE) AS expected_branded_share_kwp,  
    CAST(expected_searches_non_brand_kwp_daily AS DOUBLE) AS expected_nonbranded_kwp,
    
    -- Audit fields
    CURRENT_TIMESTAMP() AS sys_audit_created_on,
    CURRENT_TIMESTAMP() AS sys_audit_updated_on
    
  FROM data_products_prd.data_manual.ext__marketing__brand_comms__marketing_brand_nobrand_daily_goals
  
  -- Basic data quality filters
  WHERE date IS NOT NULL
    AND country IS NOT NULL
    AND date >= DATE('2025-01-01')  -- Focus on current/future goals
),

validated_goals AS (
  SELECT *
  FROM base_goals
  WHERE 
    -- Ensure at least one goal metric is provided
    (expected_branded_sc IS NOT NULL 
     OR expected_branded_share_kwp IS NOT NULL 
     OR expected_nonbranded_kwp IS NOT NULL)
    -- Validate goal values are non-negative
    AND (expected_branded_sc IS NULL OR expected_branded_sc >= 0)
    AND (expected_branded_share_kwp IS NULL OR (expected_branded_share_kwp >= 0 AND expected_branded_share_kwp <= 1))
    AND (expected_nonbranded_kwp IS NULL OR expected_nonbranded_kwp >= 0)
)

SELECT 
  date,
  country,
  expected_branded_sc,
  expected_branded_share_kwp,
  expected_nonbranded_kwp,
  sys_audit_created_on,
  sys_audit_updated_on
FROM validated_goals
