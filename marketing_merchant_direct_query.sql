-- Query equivalente a marketing_merchant_info_refined usando tablas directas
-- Recreca los mismos campos sin depender de modelos DBT que se actualizan 1x por día

WITH 
-- Base store information
base_store_info AS (
  SELECT 
    id AS store_id,
    created_at,
    country AS country_code,
    domain,
    first_payment,
    current_segment,
    email_marketing,
    plan AS plan_id_nk,
    main_user_id,
    partner_id,
    partnership_type
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4  -- excluir tiendas eliminadas
),

-- Country information
countries AS (
  SELECT 
    code AS country_code,
    name AS country_name
  FROM hive_metastore.moltres.mwp_countries
),

-- Store settings for contacts and social
store_settings AS (
  SELECT
    store_id,
    phone,
    whatsapp_phone_number AS whatsapp,
    CASE
      WHEN owner_phone_number LIKE '+%' THEN owner_phone_number
      WHEN owner_phone_country IS NOT NULL 
        OR owner_phone_area IS NOT NULL
        OR owner_phone_number IS NOT NULL
      THEN CONCAT(
        '+',
        COALESCE(owner_phone_country, ''),
        COALESCE(owner_phone_area, ''),
        COALESCE(owner_phone_number, '')
      )
      ELSE NULL
    END AS owner_phone,
    -- Social links
    NULLIF(TRIM(instagram), '') AS instagram,
    NULLIF(TRIM(facebook), '') AS facebook,
    NULLIF(TRIM(twitter), '') AS twitter,
    NULLIF(TRIM(tiktok), '') AS tiktok,
    NULLIF(TRIM(pinterest), '') AS pinterest,
    business_id
  FROM hive_metastore.moltres.mwp_store_settings
),

-- Store name from i18n
store_names AS (
  SELECT 
    ss.store_id,
    NULLIF(TRIM(i18n.name), '') AS store_name
  FROM (
    SELECT 
      ss.store_id,
      i18n.name,
      ROW_NUMBER() OVER (PARTITION BY ss.store_id ORDER BY i18n.id DESC) AS rnk
    FROM hive_metastore.moltres.mwp_store_settings ss
    LEFT JOIN hive_metastore.moltres.mwp_store_settings_i18n i18n
      ON ss.id = i18n.store_setting_id
  ) ranked
  WHERE rnk = 1
),

-- Document information from invoice_info
doc_info AS (
  SELECT
    store_id,
    CASE
      WHEN UPPER(TRIM(id_type)) IN ('CNPJ','CPF','CUIT','RUT','RFC','DNI') 
      THEN UPPER(TRIM(id_type))
      ELSE 'UNKNOWN'
    END AS doc_type,
    CASE
      WHEN UPPER(TRIM(id_type)) IN ('CNPJ','CPF','CUIT','RUT','RFC','DNI')
      THEN REGEXP_REPLACE(TRIM(id_number), '[^0-9A-Z]', '')
      ELSE NULL
    END AS doc_number
  FROM (
    SELECT
      store_id,
      id_type,
      id_number,
      ROW_NUMBER() OVER (
        PARTITION BY store_id
        ORDER BY CASE UPPER(TRIM(id_type))
                   WHEN 'CNPJ' THEN 0 WHEN 'CPF' THEN 0 WHEN 'CUIT' THEN 0
                   WHEN 'RUT'  THEN 0 WHEN 'RFC' THEN 0 WHEN 'DNI'  THEN 0
                   ELSE 9 END,
                 name ASC
      ) AS rn
    FROM hive_metastore.moltres.mwp_invoice_info
  ) ranked_docs
  WHERE rn = 1
),

-- User email information
user_emails AS (
  SELECT
    store_id,
    id AS main_user_id,
    user_email
  FROM (
    SELECT
      store_id,
      id,
      user_email,
      ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY id DESC) AS rn
    FROM hive_metastore.moltres.wp_users
  ) ranked_users
  WHERE rn = 1
),

-- Instagram stats (latest)
instagram_stats AS (
  SELECT
    store_id,
    followers AS instagram_followers,
    following,
    posts,
    CASE WHEN posts_likes >= 0 THEN posts_likes ELSE NULL END AS posts_likes
  FROM (
    SELECT
      store_id, 
      followers, 
      following, 
      posts, 
      posts_likes,
      ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY date DESC) AS rn
    FROM hive_metastore.moltres.instagram_store_info
  ) ranked_ig
  WHERE rn = 1
),

-- Location information (simplified - using basic country mapping)
-- Para obtener regiones/estados/ciudades necesitarías también las tablas de zipcodes y locations
-- Por ahora solo incluyo país
location_info AS (
  SELECT 
    bsi.store_id,
    bsi.country_code,
    c.country_name,
    -- Estas se pueden completar con más lógica si necesitas location detallada
    CAST(NULL AS STRING) AS base_region_name,
    CAST(NULL AS STRING) AS base_state_name, 
    CAST(NULL AS STRING) AS base_city_name
  FROM base_store_info bsi
  LEFT JOIN countries c ON bsi.country_code = c.country_code
),

-- Segment mapping (simplificado - necesitarías la tabla de segments)
segment_info AS (
  SELECT
    store_id,
    current_segment,
    CASE
      WHEN current_segment IS NULL OR LOWER(TRIM(current_segment)) IN ('not informed','not_informed')
      THEN 'Not Informed'
      WHEN LOWER(TRIM(current_segment)) IN ('no-seller','struggling-seller')
      THEN 'No-seller'  
      ELSE 'Seller'
    END AS segment_classification,
    -- Estos campos requerirían más lógica con las tablas de dimensiones
    CAST(NULL AS STRING) AS current_segment_name,
    CAST(NULL AS STRING) AS business_size_name,
    CAST(NULL AS STRING) AS group_name,
    CAST(NULL AS STRING) AS vertical_name
  FROM base_store_info
),

-- Attribution (simplificado - esto requiere el modelo marketing_attribution_model)
-- Por ahora campos en NULL, necesitarías replicar esa lógica también
attribution_info AS (
  SELECT
    store_id,
    CAST(NULL AS STRING) AS mkt_source_last_click,
    CAST(NULL AS STRING) AS mkt_subteam_last_click,
    CAST(NULL AS STRING) AS mkt_source_first_click,
    CAST(NULL AS STRING) AS mkt_subteam_first_click,
    CAST(NULL AS STRING) AS partner_code
  FROM base_store_info
)

-- Query final
SELECT 
  bsi.store_id,
  bsi.created_at,
  sn.store_name,
  bsi.domain,
  COALESCE(ue.user_email, bsi.email_marketing) AS email_contact,
  ss.owner_phone AS phone_contact,
  ai.partner_code,
  li.country_code AS country,
  li.base_region_name AS region,
  li.base_state_name AS province,  
  li.base_city_name AS city,
  si.current_segment_name AS segment,
  si.business_size_name AS business_size,
  si.group_name AS plan_group,
  si.vertical_name AS vertical_vertifier,
  ai.mkt_source_last_click AS team_last_click,
  ai.mkt_subteam_last_click AS subteam_last_click,
  bsi.first_payment

FROM base_store_info bsi
LEFT JOIN location_info li ON bsi.store_id = li.store_id  
LEFT JOIN store_settings ss ON bsi.store_id = ss.store_id
LEFT JOIN store_names sn ON bsi.store_id = sn.store_id
LEFT JOIN doc_info di ON bsi.store_id = di.store_id
LEFT JOIN user_emails ue ON bsi.store_id = ue.store_id
LEFT JOIN instagram_stats ig ON bsi.store_id = ig.store_id
LEFT JOIN segment_info si ON bsi.store_id = si.store_id
LEFT JOIN attribution_info ai ON bsi.store_id = ai.store_id

WHERE li.country_code IN ('AR')

-- NOTAS IMPORTANTES:
-- 1. Esta query está simplificada y no incluye toda la lógica compleja del modelo DBT original
-- 2. Los campos de attribution (marketing teams) requieren replicar la lógica del modelo marketing_attribution_model
-- 3. Los campos de segment/business_size/vertical requieren las tablas de dimensiones y seeds
-- 4. La información de location (region/state/city) requiere lógica de zipcode mapping
-- 5. Los campos de partner information requieren el modelo partners_agencies_affiliates_stores

-- Para una implementación completa, necesitarías:
-- - Replicar marketing_attribution_model logic
-- - Incluir las tablas de dimensiones (segments, verticals, business_size, etc.)
-- - Agregar la lógica de location mapping con zipcodes
-- - Incluir partners logic
