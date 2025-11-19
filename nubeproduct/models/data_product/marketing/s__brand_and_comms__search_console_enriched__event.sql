{{
  config(
    materialized='incremental',
    tags=['daily-9am'],
    unique_key=['date', 'country', 'search_query', 'device'],
    on_schema_change='fail'
  )
}}

WITH base_data AS (
  SELECT * 
  FROM {{ ref('_int_marketing_google_search_console_clean') }}
),

brand_detection AS (
  SELECT *,
    -- D2C Brand Detection
    {{ get_d2c_brand_detection('country', 'search_query') }} AS d2c_detected,
    
    -- Marketplace Brand Detection  
    {{ get_marketplace_brand_detection('country', 'search_query') }} AS marketplace_detected
    
  FROM base_data
),

nonbranded_detection AS (
  SELECT *,
    -- Non-branded Detection (only if no brands detected)
    CASE 
      WHEN d2c_detected.brand_name IS NULL AND marketplace_detected.brand_name IS NULL
      THEN {{ get_nonbranded_terms_detection('search_query') }}
      ELSE STRUCT(CAST(NULL AS STRING) AS term, CAST(NULL AS STRING) AS category, CAST(NULL AS STRING) AS match_type)
    END AS nonbranded_detected
    
  FROM brand_detection
),

enriched_data AS (
  SELECT *,
    -- Extract brand fields
    d2c_detected.brand_name AS d2c_brand_names,
    marketplace_detected.brand_name AS marketplace_brand_names,
    d2c_detected.match_type AS d2c_match_type,
    marketplace_detected.match_type AS marketplace_match_type,
    
    -- Extract non-branded fields
    nonbranded_detected.term AS non_brand_term,
    nonbranded_detected.category AS non_brand_category, 
    nonbranded_detected.match_type AS non_brand_match_type,
    
    -- Official brand flags (solo aplicar cuando NO es evolution/next)
    CASE 
      -- Si contiene evolution/next, no está en listas oficiales
      WHEN (
        -- Marcas base detectadas
        (CONTAINS(LOWER(search_query), 'tiendanube') OR 
         CONTAINS(LOWER(search_query), 'tienda nube') OR
         (country = 'BR' AND (
           CONTAINS(LOWER(search_query), 'nuvemshop') OR 
           CONTAINS(LOWER(search_query), 'nuvem shop')
         )))
        AND
        -- CON términos evolution/next por región
        ((country IN ('MX', 'AR', 'CO', 'PE', 'CL') AND (
          CONTAINS(LOWER(search_query), 'evolucion') OR
          CONTAINS(LOWER(search_query), 'evolución') OR 
          CONTAINS(LOWER(search_query), 'evolution')
        )) OR
        (country = 'BR' AND CONTAINS(LOWER(search_query), 'next')))
      ) THEN false
      ELSE {{ get_official_d2c_flag('country', 'd2c_detected.brand_name') }}
    END AS flag_d2c_oficial,
    
    CASE 
      -- Si contiene evolution/next, no está en listas oficiales
      WHEN (
        -- Marcas base detectadas
        (CONTAINS(LOWER(search_query), 'tiendanube') OR 
         CONTAINS(LOWER(search_query), 'tienda nube') OR
         (country = 'BR' AND (
           CONTAINS(LOWER(search_query), 'nuvemshop') OR 
           CONTAINS(LOWER(search_query), 'nuvem shop')
         )))
        AND
        -- CON términos evolution/next por región
        ((country IN ('MX', 'AR', 'CO', 'PE', 'CL') AND (
          CONTAINS(LOWER(search_query), 'evolucion') OR
          CONTAINS(LOWER(search_query), 'evolución') OR 
          CONTAINS(LOWER(search_query), 'evolution')
        )) OR
        (country = 'BR' AND CONTAINS(LOWER(search_query), 'next')))
      ) THEN false
      ELSE {{ get_official_marketplace_flag('country', 'marketplace_detected.brand_name') }}
    END AS flag_marketplace_oficial,
    
    -- Tiendanube/Nuvemshop Detection
    CASE WHEN (
      -- Tiendanube base (todos los países)
      CONTAINS(LOWER(search_query), 'tiendanube') OR 
      CONTAINS(LOWER(search_query), 'tienda nube') OR
      -- Nuvemshop solo para BR
      (country = 'BR' AND (
        CONTAINS(LOWER(search_query), 'nuvemshop') OR 
        CONTAINS(LOWER(search_query), 'nuvem shop')
      )) OR
      -- México variantes
      CONTAINS(LOWER(search_query), 'tiendanube mexico') OR
      CONTAINS(LOWER(search_query), 'tiendanube méxico') OR
      CONTAINS(LOWER(search_query), 'tienda nube mexico') OR
      CONTAINS(LOWER(search_query), 'tienda nube méxico') OR
      -- Colombia, Chile, Peru variantes
      CONTAINS(LOWER(search_query), 'tiendanube colombia') OR
      CONTAINS(LOWER(search_query), 'tienda nube colombia') OR
      CONTAINS(LOWER(search_query), 'tiendanube chile') OR
      CONTAINS(LOWER(search_query), 'tienda nube chile') OR
      CONTAINS(LOWER(search_query), 'tiendanube peru') OR
      CONTAINS(LOWER(search_query), 'tiendanube perú') OR
      CONTAINS(LOWER(search_query), 'tienda nube peru') OR
      CONTAINS(LOWER(search_query), 'tienda nube perú')
    ) THEN true ELSE false END AS is_nuvemshop_tiendanube,
    
    -- Next Evolution Detection
    CASE WHEN (
      -- Marcas base por país
      (CONTAINS(LOWER(search_query), 'tiendanube') OR 
       CONTAINS(LOWER(search_query), 'tienda nube') OR
       (country = 'BR' AND (
         CONTAINS(LOWER(search_query), 'nuvemshop') OR 
         CONTAINS(LOWER(search_query), 'nuvem shop')
       )))
      AND
      -- Términos evolution/next por región
      ((country IN ('MX', 'AR', 'CO', 'PE', 'CL') AND (
        CONTAINS(LOWER(search_query), 'evolucion') OR
        CONTAINS(LOWER(search_query), 'evolución') OR 
        CONTAINS(LOWER(search_query), 'evolution')
      )) OR
      (country = 'BR' AND CONTAINS(LOWER(search_query), 'next')))
    ) THEN true ELSE false END AS is_next_evolucion,
    
    -- Branded/Non-branded Classification
    CASE 
      WHEN d2c_detected.brand_name IS NOT NULL 
        OR marketplace_detected.brand_name IS NOT NULL 
      THEN 'branded'
      ELSE 'nonbranded'
    END AS branded_non_branded,
    
    -- Non-acquisition detection (only for Tiendanube/Nuvemshop queries)
    CASE 
      WHEN is_nuvemshop_tiendanube = true 
      THEN {{ get_nonacquisition_terms_detection('search_query') }}
      ELSE CAST(NULL AS STRING)
    END AS non_adquisition_terms,
    
    CASE 
      WHEN is_nuvemshop_tiendanube = true 
        AND {{ get_nonacquisition_terms_detection('search_query') }} IS NOT NULL
      THEN true
      ELSE false
    END AS is_non_adquisition_term,
    
    -- Date Dimensions
    {{ get_date_dimensions('date') }} AS date_dimensions,
    
    -- Add placeholder fields for future use
    CAST(NULL AS INT) AS expected_bs_m,
    CAST(NULL AS INT) AS expected_bs_q

  FROM nonbranded_detection
)

SELECT 
  -- Core dimensions
  date,
  date_dimensions.day AS date_day,
  date_dimensions.month AS date_month,
  date_dimensions.quarter AS date_quarter,
  date_dimensions.week AS date_week,
  date_dimensions.year AS date_year,
  date_dimensions.day_of_week AS date_day_of_week,
  
  -- Geographic dimensions
  country_detail,
  country,
  
  -- Search core
  search_query,
  
  -- Brand detection
  d2c_brand_names,
  marketplace_brand_names,
  d2c_match_type, 
  marketplace_match_type,
  is_nuvemshop_tiendanube,
  is_next_evolucion,
  
  -- Non-branded detection
  non_brand_term,
  non_brand_category,
  non_brand_match_type,
  
  -- Classification
  branded_non_branded,
  
  -- Non-acquisition detection
  non_adquisition_terms,
  is_non_adquisition_term,
  
  -- Official brand flags
  flag_d2c_oficial,
  flag_marketplace_oficial,
  
  -- Technical dimensions
  device,
  site,
  
  -- Metrics
  impressions,
  clicks,
  average_position,
  
  -- CTR calculation
  CASE 
    WHEN impressions > 0 THEN CAST(clicks AS DOUBLE) / CAST(impressions AS DOUBLE)
    ELSE 0
  END AS click_through_rate,
  
  -- Audit fields
  sys_audit_created_on,
  sys_audit_updated_on

FROM enriched_data

{% if is_incremental() %}
  -- this filter will only be applied on an incremental run
  WHERE date > (SELECT MAX(date) FROM {{ this }})
{% endif %}
