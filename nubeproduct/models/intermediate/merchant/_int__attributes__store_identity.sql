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
latest_name_description as (
  select store_id, nullif(trim(name), '') as store_name, store_description, sys_audit_updated_on
  from (
    select
      ss.store_id,
      i18n.name,
      i18n.description as store_description,
      i18n.sys_audit_updated_on,
      row_number() over (partition by ss.store_id order by i18n.id desc) as rnk
    from {{ source('int_moltres','mwp_store_settings') }} ss
    left join {{ source('int_moltres','mwp_store_settings_i18n') }} i18n
      on ss.id = i18n.store_setting_id
  ) t
  where rnk = 1
),


-- mejor candidato de doc desde invoice_info
merchant_id as (
  select
    m.store_id,
    upper(trim(m.id_type)) as id_type,
    trim(m.id_number)      as id_number,
    row_number() over (
      partition by m.store_id
      order by case upper(trim(m.id_type))
                 when 'CNPJ' then 0 when 'CPF' then 0 when 'CUIT' then 0
                 when 'RUT'  then 0 when 'RFC' then 0 when 'DNI'  then 0
                 else 9 end,
               m.name asc
    ) as rn
  from {{ source('int_moltres','mwp_invoice_info') }} m
),

-- fallback: business_id si no hay invoice_info
biz as (
  select
    ss.store_id,
    trim(ss.business_id) as business_id
  from {{ source('int_moltres','mwp_store_settings') }} ss
),

docs as (
  select
    b.store_id,
    case
      when mi.id_type in ('CNPJ','CPF','CUIT','RUT','RFC','DNI') then mi.id_type
      when bz.business_id is not null then 'UNKNOWN'
      else null
    end as doc_type,
    nullif(
      case
        when mi.id_type in ('CNPJ','CPF','CUIT','RUT','RFC','DNI')
          then regexp_replace(mi.id_number, '[^0-9A-Z]', '')
        else regexp_replace(bz.business_id, '[^0-9A-Z]', '')
      end
    , '') as doc_number
  from store_base b
  left join (select * from merchant_id where rn = 1) mi on b.store_id = mi.store_id
  left join biz bz on b.store_id = bz.store_id
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
        -- Facebook Pixel: flag si tiene fb_pixel configurado
        CASE WHEN fb_pixel IS NOT NULL THEN 'Yes' ELSE 'No' END AS pixel_fb,
        sys_audit_updated_on
    FROM {{ source('stg_moltres', 'mwp_store_settings') }}
),

-- Facebook API Conversión (CAPI)
facebook_capi AS (
    SELECT
        store_id,
        'Yes' AS capi_status
    FROM {{ source('stg_moltres', 'mwp_facebook_bussiness_extension') }}
    WHERE deleted_at IS NULL
        AND capi_status = 1
    GROUP BY store_id
),

-- 2FA Status por tienda
twofa_status AS (
    SELECT
        wu.store_id,
        COUNT(DISTINCT mfa.user_id) AS users_w_2fa_act,
        COUNT(DISTINCT wu.id) AS store_users,
        CASE
            WHEN COUNT(DISTINCT mfa.user_id) = 0 THEN 'Completamente desactivado'
            WHEN COUNT(DISTINCT mfa.user_id) = COUNT(DISTINCT wu.id) THEN '2FA completamente activado'
            WHEN COUNT(DISTINCT mfa.user_id) < COUNT(DISTINCT wu.id) THEN 'Parcialmente activado'
            ELSE 'No informado'
        END AS twofa_status
    FROM {{ source('int_moltres', 'wp_users') }} wu
    LEFT JOIN (
        SELECT 
            CAST(user_id AS BIGINT) AS user_id
        FROM {{ source('bronze_risk_new_admin', 'auth_authentication_factors') }}
        WHERE enabled = 1 AND type = 'TOTP'
    ) mfa ON mfa.user_id = wu.id
    WHERE wu.deleted = 0
    GROUP BY wu.store_id
),

-- Social Ads (TikTok, Google Ads, Google Merchant Center, Google User)
-- Identificamos tiendas con integraciones activas (última instalación no eliminada)
base_tiktok_raw AS (
    SELECT
        storeid AS store_id,
        createdat,
        deletedat,
        ROW_NUMBER() OVER (PARTITION BY storeid ORDER BY createdat DESC) AS rn
    FROM {{ source('stg_curated_social', 'tiktok_user') }}
    WHERE deletedat IS NULL
),
base_tiktok AS (
    SELECT DISTINCT store_id
    FROM base_tiktok_raw
    WHERE rn = 1
),
base_google_ads_raw AS (
    SELECT
        storeid AS store_id,
        createdat,
        deletedat,
        ROW_NUMBER() OVER (PARTITION BY storeid ORDER BY createdat DESC) AS rn
    FROM {{ source('stg_curated_social', 'google_ads_account') }}
    WHERE deletedat IS NULL
),
base_google_ads AS (
    SELECT DISTINCT store_id
    FROM base_google_ads_raw
    WHERE rn = 1
),
base_merchant_center_raw AS (
    SELECT
        storeid AS store_id,
        createdat,
        deletedat,
        ROW_NUMBER() OVER (PARTITION BY storeid ORDER BY createdat DESC) AS rn
    FROM {{ source('stg_curated_social', 'google_merchant_center_account') }}
    WHERE deletedat IS NULL
),
base_merchant_center AS (
    SELECT DISTINCT store_id
    FROM base_merchant_center_raw
    WHERE rn = 1
),
base_google_user_raw AS (
    SELECT
        storeid AS store_id,
        createdat,
        deletedat,
        ROW_NUMBER() OVER (PARTITION BY storeid ORDER BY createdat DESC) AS rn
    FROM {{ source('stg_curated_social', 'google_user') }}
    WHERE deletedat IS NULL
),
base_google_user AS (
    SELECT DISTINCT store_id
    FROM base_google_user_raw
    WHERE rn = 1
),
social_ads AS (
    SELECT
        sc.store_id,
        CASE WHEN t.store_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS tiktok_ads,
        CASE WHEN ga.store_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS google_ads,
        CASE WHEN mc.store_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS google_mc,
        CASE WHEN gu.store_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS google_user
    FROM {{ ref('s__attributes__store_core__ref') }} sc
    LEFT JOIN base_tiktok t ON sc.store_id = t.store_id
    LEFT JOIN base_google_ads ga ON sc.store_id = ga.store_id
    LEFT JOIN base_merchant_center mc ON sc.store_id = mc.store_id
    LEFT JOIN base_google_user gu ON sc.store_id = gu.store_id
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
            FROM {{ source('stg_moltres', 'mwp_options') }} opt
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
    
    -- Facebook Pixel y CAPI
    ss.pixel_fb,
    COALESCE(fc.capi_status, 'No') AS capi_status,
    
    -- 2FA Status
    COALESCE(tf.twofa_status, 'No informado') AS twofa_status,
    
    -- Social Ads (TikTok, Google Ads, Google MC, Google User)
    sa.tiktok_ads,
    sa.google_ads,
    sa.google_mc,
    sa.google_user,

    -- Tema
    tl.active_theme,
    tl.first_date_config_theme,
    tl.last_date_config_theme,

    -- Informacion de instalacion de APP nuvemshop/Tendanube
    ai.tiendanube_app_installed_at,

    -- Auditoría incremental
    -- Nota: Los nuevos CTEs (facebook_capi, twofa_status, social_ads) se detectarán automáticamente
    -- porque dependen de fuentes que ya están incluidas:
    -- - facebook_capi: cambios en mwp_store_settings (ss.sys_audit_updated_on) detectarán cambios en pixel_fb
    -- - twofa_status: cambios en wp_users (mu.sys_audit_updated_on) detectarán cambios en 2FA
    -- - social_ads: cambios se detectarán cuando cambien los modelos staging que consumen
    greatest(
        sb.sys_audit_updated_on, 
        nd.sys_audit_updated_on, 
        ss.sys_audit_updated_on, 
        mu.sys_audit_updated_on, 
        tl.last_date_config_theme, 
        ai.tiendanube_app_installed_at
    ) as change_timestamp

FROM store_base sb
LEFT JOIN latest_name_description nd ON sb.store_id = nd.store_id
LEFT JOIN store_settings ss ON sb.store_id = ss.store_id
LEFT JOIN docs ii ON sb.store_id = ii.store_id
LEFT JOIN main_user mu ON sb.store_id = mu.store_id AND sb.main_user_id = mu.user_id
LEFT JOIN theme_info tl ON sb.store_id = tl.store_id 
LEFT JOIN app_info ai ON sb.store_id = ai.store_id
LEFT JOIN facebook_capi fc ON sb.store_id = fc.store_id
LEFT JOIN twofa_status tf ON sb.store_id = tf.store_id
LEFT JOIN social_ads sa ON sb.store_id = sa.store_id

