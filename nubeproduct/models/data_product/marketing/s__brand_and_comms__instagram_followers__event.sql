{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['date', 'country'],
    on_schema_change='fail',
    tags=['daily-9am']
  )
}}

-- =============================================================================
-- Instagram Followers Silver Layer Model
-- =============================================================================
-- Purpose: Enriched Instagram followers data with validation and data quality checks
-- Source: Uses _int_marketing_instagram_followers_clean (intermediate layer)
-- Contains: Daily follower metrics (total, new, unfollowers) by country with validation
-- Granularity: Daily (date + country)
-- Data Quality: Validates numeric fields, handles missing dates, flags issues
-- =============================================================================

WITH base_data AS (
  SELECT * 
  FROM {{ ref('_int_marketing_instagram_followers_clean') }}
  WHERE date IS NOT NULL
    AND country IS NOT NULL
    {% if is_incremental() %}
      -- Process current day and last 2 months (in case of historical data updates)
      AND date >= ADD_MONTHS(current_date(), -2)
    {% endif %}
),

-- Deduplicate: keep first occurrence of (date, country) and flag duplicates
deduplicated_data AS (
  SELECT 
    date,
    country,
    profile_followers,
    new_followers,
    unfollowers,
    ROW_NUMBER() OVER (
      PARTITION BY date, country 
      ORDER BY date, country
    ) AS row_num,
    COUNT(*) OVER (
      PARTITION BY date, country
    ) AS dup_count
  FROM base_data
),

base_data_clean AS (
  SELECT 
    date,
    country,
    profile_followers,
    new_followers,
    unfollowers,
    -- Mark as duplicate if there's more than 1 row for (date, country)
    CASE 
      WHEN dup_count > 1 THEN 'review_dup'
      ELSE NULL
    END AS dup_status
  FROM deduplicated_data
  WHERE row_num = 1  -- Keep only first occurrence
),

-- Validate and clean numeric fields
validated_data AS (
  SELECT 
    date,
    country,
    dup_status,
    -- Try to cast to BIGINT, if fails (N/A, error, etc.) return NULL
    CASE 
      WHEN TRY_CAST(profile_followers AS BIGINT) IS NOT NULL 
      THEN TRY_CAST(profile_followers AS BIGINT)
      ELSE NULL
    END AS profile_followers_raw,
    CASE 
      WHEN TRY_CAST(new_followers AS BIGINT) IS NOT NULL 
      THEN TRY_CAST(new_followers AS BIGINT)
      ELSE NULL
    END AS new_followers_raw,
    CASE 
      WHEN TRY_CAST(unfollowers AS BIGINT) IS NOT NULL 
      THEN TRY_CAST(unfollowers AS BIGINT)
      ELSE NULL
    END AS unfollowers_raw
  FROM base_data_clean
),

-- Get previous day's profile_followers for each country (for filling missing/invalid values)
previous_followers AS (
  SELECT 
    country,
    date,
    dup_status,
    profile_followers_raw,
    new_followers_raw,
    unfollowers_raw,
    LAG(profile_followers_raw) OVER (
      PARTITION BY country 
      ORDER BY date
    ) AS previous_profile_followers
  FROM validated_data
),

-- Fill missing profile_followers with previous day's value and set status
filled_data AS (
  SELECT 
    pd.date,
    pd.country,
    -- Use previous day's value if current is NULL/invalid
    COALESCE(pd.profile_followers_raw, pd.previous_profile_followers) AS profile_followers,
    COALESCE(pd.new_followers_raw, 0) AS new_followers,
    COALESCE(pd.unfollowers_raw, 0) AS unfollowers,
    -- Set status: prioritize duplicate status, then 'review' if data issues, else 'ok'
    CASE 
      WHEN pd.dup_status IS NOT NULL THEN pd.dup_status
      WHEN pd.profile_followers_raw IS NULL 
        OR pd.new_followers_raw IS NULL 
        OR pd.unfollowers_raw IS NULL
      THEN 'review'
      ELSE 'ok'
    END AS status
  FROM previous_followers pd
),

-- Find first date with data for each country (to avoid generating dates before data exists)
first_date_per_country AS (
  SELECT 
    country,
    MIN(date) AS first_date
  FROM filled_data
  WHERE profile_followers IS NOT NULL
  GROUP BY country
),

-- Generate dates from first data date to current date for each country
{% if is_incremental() %}
all_dates_by_country AS (
  SELECT 
    fdc.country,
    EXPLODE(SEQUENCE(
      GREATEST(fdc.first_date, ADD_MONTHS(CURRENT_DATE(), -2)),
      CURRENT_DATE()
    )) AS date
  FROM first_date_per_country fdc
),
{% else %}
all_dates_by_country AS (
  SELECT 
    fdc.country,
    EXPLODE(SEQUENCE(
      GREATEST(fdc.first_date, DATE('2020-01-01')),
      CURRENT_DATE()
    )) AS date
  FROM first_date_per_country fdc
),
{% endif %}

-- Left join to detect missing dates
enriched_with_missing AS (
  SELECT 
    COALESCE(fd.date, adc.date) AS date,
    COALESCE(fd.country, adc.country) AS country,
    fd.profile_followers,
    fd.new_followers,
    fd.unfollowers,
    fd.status,
    -- If date is missing from source, mark as review
    CASE 
      WHEN fd.date IS NULL THEN 'review'
      ELSE COALESCE(fd.status, 'ok')
    END AS final_status
  FROM all_dates_by_country adc
  LEFT JOIN filled_data fd
    ON adc.date = fd.date 
    AND adc.country = fd.country
),

-- Fill missing dates with previous day's profile_followers using forward fill
final_data AS (
  SELECT 
    date,
    country,
    -- Forward fill profile_followers: use last non-null value for each country
    LAST_VALUE(profile_followers, true) OVER (
      PARTITION BY country 
      ORDER BY date 
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS profile_followers,
    COALESCE(new_followers, 0) AS new_followers,
    COALESCE(unfollowers, 0) AS unfollowers,
    final_status AS status
  FROM enriched_with_missing
  WHERE date >= DATE('2020-01-01')  -- Historical cutoff
    {% if is_incremental() %}
      -- Only process dates within incremental window
      AND date >= ADD_MONTHS(current_date(), -2)
    {% endif %}
),

enriched_data AS (
  SELECT *,
    -- Add date dimensions
    {{ get_date_dimensions('date') }} AS date_dimensions
  FROM final_data
)

SELECT
  -- Core date dimensions
  CAST(date AS DATE) AS date,
  date_dimensions.day AS date_day,
  date_dimensions.month AS date_month,
  date_dimensions.quarter AS date_quarter,
  date_dimensions.week AS date_week,
  date_dimensions.year AS date_year,
  date_dimensions.day_of_week AS date_day_of_week,
  
  -- Geography
  country,
  
  -- Instagram Followers Metrics
  profile_followers,
  new_followers,
  unfollowers,
  
  -- Data Quality Status
  status,
  
  -- Audit fields
  {% if is_incremental() %}
  COALESCE(
    (SELECT sys_audit_created_on 
     FROM {{ this }} e 
     WHERE e.date = enriched_data.date 
       AND e.country = enriched_data.country 
     LIMIT 1),
    CURRENT_TIMESTAMP()
  ) AS sys_audit_created_on,
  {% else %}
  CURRENT_TIMESTAMP() AS sys_audit_created_on,
  {% endif %}
  CURRENT_TIMESTAMP() AS sys_audit_updated_on

FROM enriched_data
WHERE date IS NOT NULL
  AND country IS NOT NULL
  AND profile_followers IS NOT NULL  -- Only keep rows where we have at least one historical value for forward-fill
