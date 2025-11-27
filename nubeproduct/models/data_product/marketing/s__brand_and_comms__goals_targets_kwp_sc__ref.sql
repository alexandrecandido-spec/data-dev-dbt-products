{{
  config(
    materialized='table',
    tags=['daily-9am']
  )
}}

-- =============================================================================
-- Marketing Goals Silver Layer Model  
-- =============================================================================
-- Purpose: Marketing targets for Search Console and Keyword Planner performance
-- Source: Uses _int_marketing_goals_kwp_sc_clean (intermediate layer)
-- Contains: Daily goals for branded/non-branded performance comparison
-- =============================================================================

WITH base_data AS (
  SELECT * 
  FROM {{ ref('_int_marketing_goals_kwp_sc_clean') }}
),

enriched_goals AS (
  SELECT 
    -- Core date and geography
    date,
    country,
    
    -- Goal metrics (already cleaned in intermediate layer)
    expected_branded_sc,
    expected_branded_share_kwp,
    expected_nonbranded_kwp,
    
    -- Add date dimensions
    {{ get_date_dimensions('date') }} AS date_dimensions,
    
    -- Goal metadata
    'data_manual_upload' AS goal_source,  -- Track source for auditing
    
    -- Audit fields from intermediate layer
    sys_audit_created_on,
    sys_audit_updated_on
    
  FROM base_data
)

SELECT
  -- Core date dimensions
  date,
  date_dimensions.day AS date_day,
  date_dimensions.month AS date_month,
  date_dimensions.quarter AS date_quarter, 
  date_dimensions.week AS date_week,
  date_dimensions.year AS date_year,
  date_dimensions.day_of_week AS date_day_of_week,
  
  -- Geography
  country,
  
  -- Goal metrics
  expected_branded_sc,
  expected_branded_share_kwp,
  expected_nonbranded_kwp,
  
  -- Goal metadata
  goal_source,
  
  -- Audit fields
  sys_audit_created_on,
  sys_audit_updated_on

FROM enriched_goals