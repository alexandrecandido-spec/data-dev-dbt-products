-- Query más completa para replicar marketing_merchant_info_refined usando tablas directas
-- Incluye lógica para partner_code, attribution básica y otros campos importantes

WITH 
-- Base de tiendas
base_stores AS (
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
  WHERE state != 4 AND country IN ('AR')  -- Solo Argentina y tiendas activas
),

-- Partner information usando las tablas de ecosystem
partners_info AS (
  SELECT 
    mp.id AS partner_id,
    mp.code AS partner_code,
    mp.name AS partner_name,
    mc.code AS partner_country_code
  FROM hive_metastore.ecosystem.mwp_partners mp
  LEFT JOIN hive_metastore.moltres.mwp_countries mc 
    ON mp.country = mc.id
),

-- Nombres de tienda
store_names AS (
  SELECT 
    store_id,
    store_name
  FROM (
    SELECT 
      ss.store_id,
      NULLIF(TRIM(i18n.name), '') AS store_name,
      ROW_NUMBER() OVER (PARTITION BY ss.store_id ORDER BY i18n.id DESC) AS rnk
    FROM hive_metastore.moltres.mwp_store_settings ss
    LEFT JOIN hive_metastore.moltres.mwp_store_settings_i18n i18n
      ON ss.id = i18n.store_setting_id
  ) ranked
  WHERE rnk = 1
),

-- Información de contacto
contacts AS (
  SELECT
    store_id,
    phone,
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
    END AS owner_phone
  FROM hive_metastore.moltres.mwp_store_settings
),

-- Email de usuarios
user_emails AS (
  SELECT
    store_id,
    user_email
  FROM (
    SELECT
      store_id,
      user_email,
      ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY id DESC) AS rn
    FROM hive_metastore.moltres.wp_users
  ) ranked
  WHERE rn = 1
),

-- País y ubicación básica
location_info AS (
  SELECT 
    bs.store_id,
    bs.country_code,
    cn.name AS country_name,
    -- Para region/state/city completas necesitarías más lógica con shipping locations
    CAST(NULL AS STRING) AS base_region_name,
    CAST(NULL AS STRING) AS base_state_name,
    CAST(NULL AS STRING) AS base_city_name
  FROM base_stores bs
  LEFT JOIN hive_metastore.moltres.mwp_countries cn 
    ON bs.country_code = cn.code
),

-- Marketing attribution básica desde mwp_attribution
-- Esta es una versión simplificada - el modelo completo es mucho más complejo
marketing_attribution AS (
  SELECT
    att.store_id,
    -- Obtener last click attribution
    FIRST_VALUE(att.utm_source) OVER (
      PARTITION BY att.store_id 
      ORDER BY att.click_timestamp DESC 
      ROWS UNBOUNDED PRECEDING
    ) AS mkt_source_last_click,
    FIRST_VALUE(att.utm_medium) OVER (
      PARTITION BY att.store_id 
      ORDER BY att.click_timestamp DESC 
      ROWS UNBOUNDED PRECEDING  
    ) AS mkt_subteam_last_click,
    -- Esta lógica es muy simplificada comparada con el modelo real
    ROW_NUMBER() OVER (PARTITION BY att.store_id ORDER BY att.click_timestamp DESC) AS rn
  FROM hive_metastore.moltres.mwp_attribution att
  INNER JOIN base_stores bs ON att.store_id = bs.store_id
),

-- Filtrar solo el último click por tienda
attribution_last_click AS (
  SELECT
    store_id,
    mkt_source_last_click,
    mkt_subteam_last_click
  FROM marketing_attribution
  WHERE rn = 1
),

-- Segmento simplificado 
-- Para la versión completa necesitarías la lógica de payments y el seed de segments
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
    END AS segment_classification
  FROM base_stores
),

-- Query final
final_result AS (
  SELECT 
    bs.store_id,
    bs.created_at,
    sn.store_name,
    bs.domain,
    COALESCE(ue.user_email, bs.email_marketing) AS email_contact,
    c.owner_phone AS phone_contact,
    
    -- Partner code desde ecosystem.mwp_partners
    pi.partner_code,
    
    bs.country_code AS country,
    li.base_region_name AS region,
    li.base_state_name AS province,
    li.base_city_name AS city,
    
    -- Segment (simplificado)
    si.current_segment AS segment,
    
    -- Estos campos requieren lógica adicional más compleja:
    CAST(NULL AS STRING) AS business_size,    -- Necesita vertifier + dim_business_size
    CAST(NULL AS STRING) AS plan_group,       -- Necesita dim_group_plan + mapeo de plans
    CAST(NULL AS STRING) AS vertical_vertifier, -- Necesita vertifier + dim_vertical_type
    
    -- Marketing attribution (versión simplificada)
    alc.mkt_source_last_click AS team_last_click,
    alc.mkt_subteam_last_click AS subteam_last_click,
    
    bs.first_payment

  FROM base_stores bs
  LEFT JOIN store_names sn ON bs.store_id = sn.store_id
  LEFT JOIN contacts c ON bs.store_id = c.store_id  
  LEFT JOIN user_emails ue ON bs.store_id = ue.store_id
  LEFT JOIN location_info li ON bs.store_id = li.store_id
  LEFT JOIN partners_info pi ON bs.partner_id = pi.partner_id
  LEFT JOIN attribution_last_click alc ON bs.store_id = alc.store_id  
  LEFT JOIN segment_info si ON bs.store_id = si.store_id
)

-- Estructura final igual a tu CTE original
SELECT 
  store_id,
  created_at,
  store_name,
  domain,
  email_contact,
  phone_contact,
  partner_code,
  country,
  region,
  province,
  city,
  segment,
  business_size,
  plan_group,
  vertical_vertifier,
  team_last_click,
  subteam_last_click,
  first_payment
FROM final_result

/*
NOTAS SOBRE LOS CAMPOS QUE FALTAN Y CÓMO COMPLETARLOS:

1. **Location detallada (region/province/city)**:
   Necesitas usar hive_metastore.shipping.locations y mapear con:
   - mwp_zipcodes_ar 
   - mwp_provinces
   - regions  
   - mwp_cities_ar

2. **Business Size & Vertical**:
   Necesitas:
   - hive_metastore.antifraud_service.vertifier_store_inferences
   - Seeds: dimensions__segment_type, etc.
   - Lógica de mapeo de verticals

3. **Plan Group**:
   Necesitas:
   - hive_metastore.moltres.mwp_plans
   - Seed: operations__grouping_plans_aux
   - Mapeo de plan_id_nk a group names

4. **Marketing Attribution completo**:
   La lógica real es mucho más compleja e incluye:
   - Attribution externa desde hive_metastore.attribution.store_attributions_external
   - Lógica de first/last click 
   - Clasificación de utm_source/medium en teams/subteams
   - Trials flags y scoring

5. **Segments detallados**:
   Necesitas el seed dimensions__segment_type y lógica de:
   - Payment history analysis
   - Segment transitions over time
*/
