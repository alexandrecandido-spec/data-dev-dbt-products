-- =============================================================================
-- Instagram Followers Intermediate - Clean Data
-- =============================================================================
-- Purpose: Clean and unify raw Instagram followers data from manual uploads
-- Responsibilities:
--   - Unify 3 country-specific tables (BR, MX, AR) into single table
--   - Add country field to each record
--   - Basic data type casting
--   - Filter out invalid dates
-- Next Layer: s__brand_and_comms__instagram_followers__event (validation, enrichment, date dimensions)
-- =============================================================================

WITH instagram_br AS (
  SELECT 
    date,
    'BR' AS country,
    profile_followers,
    new_followers,
    unfollowers
  FROM {{ source('data_manual', 'ext__marketing__brand_comms__followers_instagram_br') }}
  WHERE date IS NOT NULL
),

instagram_mx AS (
  SELECT 
    date,
    'MX' AS country,
    profile_followers,
    new_followers,
    unfollowers
  FROM {{ source('data_manual', 'ext__marketing__brand_comms__followers_instagram_mx') }}
  WHERE date IS NOT NULL
),

instagram_ar AS (
  SELECT 
    date,
    'AR' AS country,
    profile_followers,
    new_followers,
    unfollowers
  FROM {{ source('data_manual', 'ext__marketing__brand_comms__followers_instagram_ar') }}
  WHERE date IS NOT NULL
)

SELECT 
  date,
  country,
  profile_followers,
  new_followers,
  unfollowers
FROM instagram_br
UNION ALL
SELECT * FROM instagram_mx
UNION ALL
SELECT * FROM instagram_ar

