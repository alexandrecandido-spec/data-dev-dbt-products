-- ==============================================
-- QUERY 1/5: BASE STORE INFORMATION & CONTACTS
-- ==============================================
-- Esta query obtiene la información básica de tiendas, contactos, social media y documentos
-- Join key: store_id

WITH 
-- Base de tiendas (solo AR como en tu query original)
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

-- Nombres de tienda desde i18n (última versión)
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

-- Información de contacto y social desde settings
contacts_social AS (
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

-- Email de usuarios (fallback si no hay email_marketing)
user_emails AS (
  SELECT
    store_id,
    user_email,
    id AS main_user_id
  FROM (
    SELECT
      store_id,
      user_email,
      id,
      ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY id DESC) AS rn
    FROM hive_metastore.moltres.wp_users
  ) ranked
  WHERE rn = 1
),

-- Información de documentos desde invoice_info (mejor candidato)
doc_info AS (
  SELECT
    store_id,
    doc_type,
    doc_number
  FROM (
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
      END AS doc_number,
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

-- Instagram stats (latest per store)
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

-- País información
country_info AS (
  SELECT 
    code AS country_code,
    name AS country_name
  FROM hive_metastore.moltres.mwp_countries
)

-- Query final con toda la información base
SELECT 
  bs.store_id,
  bs.created_at,
  sn.store_name,
  bs.domain,
  
  -- Contacts  
  COALESCE(ue.user_email, bs.email_marketing) AS email,
  cs.phone,
  cs.whatsapp,
  cs.owner_phone,
  
  -- Document info
  di.doc_type,
  di.doc_number,
  
  -- Social media
  cs.instagram,
  ig.instagram_followers,
  ig.following,
  ig.posts,
  ig.posts_likes,
  cs.facebook,
  cs.twitter,
  cs.tiktok,
  cs.pinterest,
  
  -- Basic store data
  bs.country_code,
  ci.country_name,
  bs.current_segment,
  bs.first_payment,
  bs.plan_id_nk,
  bs.partner_id,
  bs.partnership_type,
  
  -- User info  
  COALESCE(ue.main_user_id, bs.main_user_id) AS main_user_id

FROM base_stores bs
LEFT JOIN store_names sn ON bs.store_id = sn.store_id
LEFT JOIN contacts_social cs ON bs.store_id = cs.store_id  
LEFT JOIN user_emails ue ON bs.store_id = ue.store_id
LEFT JOIN doc_info di ON bs.store_id = di.store_id
LEFT JOIN instagram_stats ig ON bs.store_id = ig.store_id
LEFT JOIN country_info ci ON bs.country_code = ci.country_code

ORDER BY bs.store_id
