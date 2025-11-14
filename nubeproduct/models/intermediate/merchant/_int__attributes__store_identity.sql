/*
Intermediate Model: Store Identity Consolidation
Description: Consolida información de identidad de la tienda desde múltiples fuentes
Owner: jhu.boggio@tiendanube.com
Domain: merchant

Este modelo intermedio consolida toda la lógica de obtención y transformación de datos de identidad:
- Información de contacto (email, teléfonos, usuario principal)
- Información de la tienda (nombre, descripción)
- Documentos fiscales (tipo y número)
- Redes sociales (Instagram, Facebook, Twitter, TikTok, Pinterest)
- Tema activo y fechas de configuración

El modelo SILVER solo consumirá este intermediate y manejará la incrementalidad.
*/

-- Información base de la tienda
WITH store_base AS (
    SELECT
        s.store_id,
        s.main_user_id,
        s.state,
        s.sys_audit_updated_on
    FROM {{ ref('merchant__attributes__store_info__ref') }} s
),

-- store_name desde i18n (última versión)
latest_name_description AS (
  SELECT store_id, nullif(trim(name), '') as store_name, store_description, sys_audit_updated_on
  FROM (
    SELECT
      ss.store_id,
      i18n.name,
      i18n.description AS store_description,
      i18n.sys_audit_updated_on,
      row_number() over (partition by ss.store_id order by i18n.id desc) as rnk
    FROM {{ source('int_moltres','mwp_store_settings') }} ss
    LEFT JOIN {{ source('int_moltres','mwp_store_settings_i18n') }} i18n ON ss.id = i18n.store_setting_id
  ) t
  WHERE rnk = 1
),


-- PRIORIDAD 1: billing.invoice_information
billing_merchant AS (
  SELECT 
  store_id,
  id_type,
  id_number
  FROM (
      SELECT
      cast(storeId as bigint) AS store_id,
      upper(trim(idType)) AS id_type,
      trim(idNumber) AS id_number,
      row_number() over (partition by storeId order by createdAt desc) AS rn
      FROM {{ source('int_billing','invoice_information') }}
  )
  WHERE rn = 1
),

-- PRIORIDAD 2: moltres.mwp_invoice_info
invoice_merchant_info AS (
  SELECT
  store_id,
  id_type,
  id_number
  FROM (
    SELECT
    cast(m.store_id as bigint) AS store_id,
    upper(trim(m.id_type)) AS id_type,
    trim(m.id_number) AS id_number,
    row_number() over (partition by m.store_id order by m.sys_audit_created_on desc) AS rn
    FROM {{ source('int_moltres','mwp_invoice_info') }} m
  )
  WHERE rn = 1
),

-- Resolver prioridad entre ambas fuentes
merchant_id AS (
  SELECT
    coalesce(b.store_id, m.store_id) AS store_id,
    coalesce(nullif(b.id_type,   ''), nullif(m.id_type,   '')) AS id_type,
    coalesce(nullif(b.id_number, ''), nullif(m.id_number, '')) AS id_number
  FROM billing_merchant b
  FULL OUTER JOIN invoice_merchant_info m on b.store_id = m.store_id
),

-- fallback: business_id si no hay invoice_info
biz as (
  SELECT
    cast(ss.store_id as bigint) AS store_id,
    trim(ss.business_id) AS business_id
  FROM {{ source('int_moltres','mwp_store_settings') }} ss
),

-- Composición final de documentos con prioridades
docs AS (
  SELECT
    b.store_id,
    CASE
      WHEN mi.id_type IN ('CNPJ','CPF','CUIT','RUT','RFC','DNI') THEN mi.id_type
      WHEN bz.business_id is not null then 'UNKNOWN'
      ELSE NULL
    END AS doc_type,
    nullif(
      CASE
        WHEN mi.id_type IN ('CNPJ','CPF','CUIT','RUT','RFC','DNI')
          THEN regexp_replace(mi.id_number, '[^0-9A-Z]', '')
        ELSE regexp_replace(bz.business_id, '[^0-9A-Z]', '')
      END, '') AS doc_number
  FROM store_base b
  LEFT JOIN merchant_id mi ON b.store_id = mi.store_id
  LEFT JOIN biz bz ON b.store_id = bz.store_id
),

-- Configuración de la tienda (teléfonos, redes sociales)
store_settings AS (
    SELECT
        store_id,
        phone AS phone_from_footer,
        owner_phone_number,
        whatsapp_phone_number AS phone_whatsapp_button,
        CASE
            WHEN owner_phone_number LIKE '+%' THEN owner_phone_number
            WHEN owner_phone_country IS NOT NULL OR owner_phone_area IS NOT NULL OR owner_phone_number IS NOT NULL
            THEN CONCAT('+', COALESCE(owner_phone_country, ''), COALESCE(owner_phone_area, ''), COALESCE(owner_phone_number, ''))
            ELSE NULL
        END AS owner_phone,
        instagram,
        facebook,
        twitter,
        tiktok,
        pinterest,
        sys_audit_updated_on
    FROM {{ source('int_stg_moltres', 'mwp_store_settings') }}
),

-- Información del usuario principal
-- Incluimos usuarios incluso si están deleted=1, porque si son el main_user_id oficial
-- de la tienda, sus datos siguen siendo válidos y la tienda los reconoce como su usuario principal
main_user AS (
    SELECT
        wu.store_id,
        wu.id AS user_id,
        wu.user_email,
        wu.first_name AS user_first_name,
        wu.last_name AS user_last_name,
        wu.user_nicename,
        wu.user_registered AS user_registered_at,
        wu.role AS user_role,
        wu.sys_audit_updated_on
    FROM {{ source('int_moltres', 'wp_users') }} wu
    -- No filtramos por deleted porque si el usuario es el main_user_id oficial,
    -- debemos incluirlo sin importar su estado de eliminación
),

-- Información del tema activo
theme_info AS (
    SELECT 
    active_theme.*
    FROM (
        SELECT
            t.store_id,
            t.active_theme,
            t.first_date_config_theme,
            t.last_date_config_theme,
            ROW_NUMBER() OVER (PARTITION BY t.store_id ORDER BY t.last_date_config_theme DESC) AS rn
        FROM (
            SELECT
                opt.store_id,
                opt.option_value AS active_theme,
                MIN(opt.created_at) AS first_date_config_theme,
                MAX(opt.created_at) AS last_date_config_theme
            FROM {{ source('int_stg_moltres', 'mwp_options') }} opt
            WHERE opt.option_name = 'twig_template'
            GROUP BY opt.store_id, opt.option_value
        ) t
    ) active_theme
    WHERE rn = 1
),

---Informacion de instalacion de APP nuvemshop/Tendanube
app_info AS (
    SELECT
    p.store_id,
    min(p.app_install_date) as tiendanube_app_installed_at
    FROM {{ ref('moltres__platform_mwp_apps_stores') }} p 
    WHERE p.app_id = 2602
    GROUP BY 1
)

SELECT
    sb.store_id,
    sb.state,
    sb.main_user_id,
    
    -- Información de la tienda
    nd.store_name,
    nd.store_description,
    
    -- Información de contacto
    mu.user_email,
    mu.user_first_name,
    mu.user_last_name,
    mu.user_nicename,
    mu.user_registered_at,
    mu.user_role,
    ss.phone_from_footer,
    ss.owner_phone_number,
    ss.phone_whatsapp_button,
    ss.owner_phone,
    
    -- Documentos fiscales
    ii.doc_type,
    ii.doc_number,
    
    -- Redes sociales
    ss.instagram,
    ss.facebook,
    ss.twitter,
    ss.tiktok,
    ss.pinterest,
    
    -- Tema
    tl.active_theme,
    tl.first_date_config_theme,
    tl.last_date_config_theme,

    -- Informacion de instalacion de APP nuvemshop/Tendanube
    ai.tiendanube_app_installed_at,

    -- Auditoría incremental
    greatest(sb.sys_audit_updated_on, nd.sys_audit_updated_on, ss.sys_audit_updated_on, mu.sys_audit_updated_on, tl.last_date_config_theme, ai.tiendanube_app_installed_at) as change_timestamp

FROM store_base sb
LEFT JOIN latest_name_description nd ON sb.store_id = nd.store_id
LEFT JOIN store_settings ss ON sb.store_id = ss.store_id
LEFT JOIN docs ii ON sb.store_id = ii.store_id
LEFT JOIN main_user mu ON sb.store_id = mu.store_id AND sb.main_user_id = mu.user_id
LEFT JOIN theme_info tl ON sb.store_id = tl.store_id 
LEFT JOIN app_info ai ON sb.store_id = ai.store_id

