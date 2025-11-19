{{
  config(
    materialized='table',
    tags=['marketing', 'search_console', 'intermediate']
  )
}}

WITH source_data AS (
  SELECT 
    -- Date conversion from timestamp to date
    DATE(date) AS date,
    
    -- Basic fields
    country_code,
    country AS country_detail,
    device,
    site,
    search_query,
    search_type,
    clicks,
    impressions,
    average_position,
    
    -- Audit fields for debugging if needed
    sys_audit_extracted_on,
    sys_audit_created_on,
    sys_audit_updated_on

  FROM {{ source('int_third_party', 'marketing_google_search_console_keyword_searches') }}
        WHERE 
          -- Filter by date range
          DATE(date) >= '2020-01-01'
    
    -- Filter by search type
    AND search_type = 'WEB'
    
    -- Filter by countries we care about
    AND country IN ('Argentina', 'Mexico', 'Brazil', 'Colombia', 'Chile', 'Peru')
    
    -- Exclude deleted records
    AND sys_audit_is_deleted = 0
    
    -- Filter out null search queries
    AND search_query IS NOT NULL
    AND search_query != '(not provided)'
    AND search_query != '(unknown)'
),

cleaned_data AS (
  SELECT 
    date,
    country_detail,
    
    -- Apply country mapping based on site
    {{ get_country_mapping('country_detail', 'site') }} AS country,
    
    search_query,
    site,
    
    -- Device rectification (null -> DESKTOP)
    CASE WHEN device IS NULL THEN 'DESKTOP' ELSE device END AS device,
    
    impressions,
    clicks,
    average_position,
    
    -- Audit fields
    sys_audit_extracted_on,
    sys_audit_created_on,
    sys_audit_updated_on

  FROM source_data
)

SELECT * 
FROM cleaned_data 
WHERE country != 'no-report'  -- Exclude unmapped countries
