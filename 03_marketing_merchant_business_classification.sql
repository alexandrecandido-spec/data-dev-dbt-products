-- ==============================================
-- QUERY 3/5: BUSINESS CLASSIFICATION (SEGMENTS/BUSINESS_SIZE/VERTICAL)
-- ==============================================
-- Esta query obtiene segments, business_size y vertical usando vertifier y dimensions
-- Join key: store_id

WITH 
-- Base de tiendas (filtro Argentina)  
base_stores AS (
  SELECT 
    id AS store_id,
    current_segment
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4 AND country IN ('AR')
),

-- Latest vertifier por tienda (desde antifraud service)
latest_vertifier AS (
  SELECT 
    store_id,
    CASE 
      WHEN vertifier IS NULL THEN 'Not Informed'
      WHEN vertifier IN ('', 'unknown') THEN 'Not Informed'
      ELSE vertifier 
    END AS vertifier_classification
  FROM (
    SELECT 
      CAST(storeid AS BIGINT) AS store_id,
      CAST(primary.name AS STRING) AS vertifier,
      ROW_NUMBER() OVER(PARTITION BY storeid ORDER BY createdat DESC) AS rnk
    FROM hive_metastore.antifraud_service.vertifier_store_inferences
  ) ranked_vertifier
  WHERE rnk = 1
),

-- Store settings para type y business_size
store_settings_info AS (
  SELECT
    store_id,
    type AS manual_type,
    business_size
  FROM hive_metastore.moltres.mwp_store_settings
),

-- Vertical classification (type manual tiene prioridad, vertifier como fallback)
vertical_classification AS (
  SELECT 
    bs.store_id,
    CASE 
      WHEN ss.manual_type IS NULL THEN lv.vertifier_classification 
      ELSE ss.manual_type 
    END AS final_vertical_name
  FROM base_stores bs
  LEFT JOIN store_settings_info ss ON bs.store_id = ss.store_id
  LEFT JOIN latest_vertifier lv ON bs.store_id = lv.store_id
),

-- Vertical dimension mapping (manual desde dbt seed aproximado)
vertical_dimension AS (
  SELECT vertical_name, vertical_id FROM VALUES
    ('clothing', 1),
    ('clothing_accesories', 2),
    ('jewelry', 3),
    ('electronics_it', 4),
    ('health_beauty', 5),
    ('food_drinks', 6),
    ('home_garden', 7),
    ('gifts', 8),
    ('bookstore_graphic', 9),
    ('books', 10),
    ('education', 11),
    ('art', 12),
    ('sports', 13),
    ('toys', 14),
    ('automotive', 15),
    ('fashion', 16),
    ('apparel', 17),
    ('accessories', 18),
    ('beauty', 19),
    ('Not Informed', -1)
  AS vd(vertical_name, vertical_id)
),

-- Business size dimension (manual desde dbt seed aproximado) 
business_size_dimension AS (
  SELECT business_size_name, business_size_id FROM VALUES
    ('large-business', 1),
    ('medium-business', 2), 
    ('small-business', 3),
    ('micro-business', 4),
    ('Not Informed', -1)
  AS bsd(business_size_name, business_size_id)
),

-- Segment dimension (manual desde dbt seed aproximado)
segment_dimension AS (
  SELECT segment_name, segment_id, segment_order FROM VALUES
    ('no-seller', 1, 1),
    ('struggling-seller', 2, 2),
    ('emerging-seller', 3, 3),
    ('growing-seller', 4, 4),
    ('established-seller', 5, 5),
    ('scaling-seller', 6, 6),
    ('Not Informed', -1, 0)
  AS sd(segment_name, segment_id, segment_order)
),

-- Segment classification mejorada (basada en current_segment + lógica de dbt)
segment_classification AS (
  SELECT
    bs.store_id,
    bs.current_segment AS raw_segment,
    CASE
      WHEN bs.current_segment IS NULL 
        OR LOWER(TRIM(bs.current_segment)) IN ('not informed','not_informed')
      THEN 'Not Informed'
      WHEN LOWER(TRIM(bs.current_segment)) IN ('no-seller','struggling-seller')
      THEN bs.current_segment
      -- Mapeo de otros segments comunes
      WHEN LOWER(TRIM(bs.current_segment)) IN ('emerging','emerging-seller')
      THEN 'emerging-seller'  
      WHEN LOWER(TRIM(bs.current_segment)) IN ('growing','growing-seller')
      THEN 'growing-seller'
      WHEN LOWER(TRIM(bs.current_segment)) IN ('established','established-seller')
      THEN 'established-seller'
      WHEN LOWER(TRIM(bs.current_segment)) IN ('scaling','scaling-seller')
      THEN 'scaling-seller'
      ELSE 'Not Informed'  -- Default para segments desconocidos
    END AS clean_segment_name,
    
    -- is_seller classification (igual que en el modelo dbt original)
    CASE
      WHEN bs.current_segment IS NULL
        OR LOWER(TRIM(bs.current_segment)) IN ('not informed','not_informed')
      THEN 'Not Informed'
      WHEN LOWER(TRIM(bs.current_segment)) IN ('no-seller','struggling-seller')
      THEN 'No-seller'
      ELSE 'Seller'
    END AS is_seller
  FROM base_stores bs
),

-- Final business classification
final_classification AS (
  SELECT 
    bs.store_id,
    
    -- Segment info
    sc.raw_segment AS current_segment_raw,
    sc.clean_segment_name AS current_segment_name,
    sc.is_seller,
    COALESCE(sd.segment_id, -1) AS segment_id,
    COALESCE(sd.segment_order, 0) AS segment_order,
    
    -- Vertical info  
    vc.final_vertical_name AS vertical_name,
    COALESCE(vd.vertical_id, -1) AS vertical_id,
    
    -- Business size info
    ss.business_size AS business_size_raw,
    COALESCE(ss.business_size, 'Not Informed') AS business_size_name,
    COALESCE(bsd.business_size_id, -1) AS business_size_id

  FROM base_stores bs
  LEFT JOIN segment_classification sc ON bs.store_id = sc.store_id
  LEFT JOIN segment_dimension sd ON sc.clean_segment_name = sd.segment_name
  LEFT JOIN vertical_classification vc ON bs.store_id = vc.store_id  
  LEFT JOIN vertical_dimension vd ON vc.final_vertical_name = vd.vertical_name
  LEFT JOIN store_settings_info ss ON bs.store_id = ss.store_id
  LEFT JOIN business_size_dimension bsd ON ss.business_size = bsd.business_size_name
)

-- Query final para join
SELECT 
  store_id,
  
  -- Segment fields (como en marketing_merchant_info_refined)
  current_segment_name,
  is_seller,
  segment_id,
  segment_order,
  
  -- Vertical fields  
  vertical_name,
  vertical_id,
  
  -- Business size fields
  business_size_name,
  business_size_id,
  
  -- Raw values para debugging si es necesario
  current_segment_raw,
  business_size_raw

FROM final_classification
ORDER BY store_id


