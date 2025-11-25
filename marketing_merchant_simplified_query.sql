-- Query simplificada para obtener los campos específicos que usas en tu marketing_merchant CTE
-- Enfocada en los campos: store_id, created_at, store_name, domain, email, phone, partner_code, 
-- country, region, province, city, segment, business_size, plan_group, vertical, mkt teams, first_payment

WITH 
-- Información base de tiendas
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
  WHERE state != 4 AND country IN ('AR')  -- Solo Argentina y no eliminadas
),

-- Nombres de tienda desde i18n
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

-- Información de contacto desde settings
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

-- Email de usuarios (fallback si no hay email_marketing)
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

-- País información
country_names AS (
  SELECT 
    code AS country_code,
    name AS country_name
  FROM hive_metastore.moltres.mwp_countries
),

-- SIMPLIFICACIONES para campos que requieren lógica más compleja:
-- Estos campos necesitarían las tablas de dimensiones completas y lógica de attribution

final_result AS (
  SELECT 
    bs.store_id,
    bs.created_at,
    sn.store_name,
    bs.domain,
    COALESCE(ue.user_email, bs.email_marketing) AS email_contact,
    c.owner_phone AS phone_contact,
    
    -- Partner code: necesitarías replicar la lógica de partners_agencies_affiliates_stores
    -- Por ahora uso el partner_id básico de mwp_store_info como fallback
    CAST(bs.partner_id AS STRING) AS partner_code,
    
    bs.country_code AS country,
    cn.country_name,
    
    -- Location: Para obtener region/province/city necesitarías:
    -- 1. Tabla de shipping locations o zipcodes
    -- 2. Mapeo con mwp_provinces, regions, cities tables
    -- Por ahora NULL hasta que implementes esa lógica
    CAST(NULL AS STRING) AS base_region_name,
    CAST(NULL AS STRING) AS base_state_name, 
    CAST(NULL AS STRING) AS base_city_name,
    
    -- Segment: necesitarías el seed dimensions__segment_type y lógica de segmentación
    -- Por ahora uso el current_segment básico
    bs.current_segment AS current_segment_name,
    
    -- Business size: necesitarías lógica de business_size_id mapping
    CAST(NULL AS STRING) AS business_size_name,
    
    -- Plan group: necesitarías dim_group_plan y mapeo con plan_id_nk
    CAST(NULL AS STRING) AS group_name,
    
    -- Vertical: necesitarías vertifier logic y dim_vertical_type
    CAST(NULL AS STRING) AS vertical_name,
    
    -- Marketing attribution: necesitarías replicar marketing_attribution_model
    -- Esto es complejo porque involucra clicks, utm params, etc.
    CAST(NULL AS STRING) AS mkt_source_last_click,
    CAST(NULL AS STRING) AS mkt_subteam_last_click,
    
    bs.first_payment

  FROM base_stores bs
  LEFT JOIN store_names sn ON bs.store_id = sn.store_id
  LEFT JOIN contacts c ON bs.store_id = c.store_id  
  LEFT JOIN user_emails ue ON bs.store_id = ue.store_id
  LEFT JOIN country_names cn ON bs.country_code = cn.country_code
)

SELECT 
  store_id,
  created_at,
  store_name,
  domain,
  email_contact,
  phone_contact,
  partner_code,
  country,
  base_region_name AS region,
  base_state_name AS province,
  base_city_name AS city,
  current_segment_name AS segment,
  business_size_name AS business_size,
  group_name AS plan_group,
  vertical_name AS vertical_vertifier,
  mkt_source_last_click AS team_last_click,
  mkt_subteam_last_click AS subteam_last_click,
  first_payment
FROM final_result

/*
PARA COMPLETAR LOS CAMPOS QUE FALTAN, NECESITARÍAS AGREGAR:

1. **Partner Code real**: 
   - Replicar la lógica de models/intermediate/partners/_int_partners__agencies_affiliates_stores_store_info.sql
   - Usar hive_metastore.ecosystem.mwp_partners

2. **Location (region/province/city)**:
   - Usar hive_metastore.shipping.locations para obtener address info
   - Mapear con mwp_zipcodes_ar, mwp_provinces, regions, mwp_cities_ar
   
3. **Segments**:
   - Usar el seed nubeproduct/seeds/dimensions__segment_type.csv
   - Aplicar lógica de segmentación por payments history

4. **Business Size & Vertical**:
   - Usar vertifier logic desde antifraud_service.vertifier_store_inferences
   - Mapear con dimensiones de business_size y vertical_type

5. **Marketing Attribution (team_last_click, subteam_last_click)**:
   - Replicar models/data_product/marketing/marketing_attribution_model.sql
   - Usar moltres.mwp_attribution + attribution.store_attributions_external
   - Aplicar lógica de first/last click attribution

6. **Plan Group**:
   - Mapear plan_id_nk con mwp_plans y el seed operations__grouping_plans_aux.csv
*/
