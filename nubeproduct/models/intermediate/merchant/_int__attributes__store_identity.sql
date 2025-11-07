{{
    config(
        materialized='ephemeral'
    )
}}

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
        s.main_user_id
    FROM {{ ref('s__attributes__store_core__ref') }} s
    WHERE s.created_at > '2024-01-01'
),

-- Información i18n de la tienda (nombre y descripción)
store_i18n AS (
    SELECT
        store_id,
        store_name,
        store_description
    FROM {{ source('int_moltres', 'mwp_store_settings_i18n') }}
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
        pinterest
    FROM {{ source('stg_moltres', 'mwp_store_settings') }}
),

-- Información de documentos fiscales
invoice_info AS (
    SELECT
        store_id,
        id_type AS doc_type,
        id_number AS doc_number
    FROM {{ source('stg_moltres', 'mwp_invoice_info') }}
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
        wu.user_registered_at,
        wu.user_role
    FROM {{ source('int_moltres', 'wp_users') }} wu
    -- No filtramos por deleted porque si el usuario es el main_user_id oficial,
    -- debemos incluirlo sin importar su estado de eliminación
),

-- Información del tema activo
theme_info AS (
    SELECT
        opt.store_id,
        opt.option_value AS active_theme,
        MIN(opt.created_at) AS first_date_config_theme,
        MAX(opt.created_at) AS last_date_config_theme
    FROM {{ source('stg_moltres', 'mwp_options') }} opt
    WHERE opt.option_name = 'twig_template'
    GROUP BY opt.store_id, opt.option_value
),

-- Obtener el tema más reciente por tienda
theme_latest AS (
    SELECT
        store_id,
        active_theme,
        first_date_config_theme,
        last_date_config_theme,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY last_date_config_theme DESC) AS rn
    FROM theme_info
)

SELECT
    sb.store_id,
    sb.main_user_id,
    
    -- Información de la tienda
    si18n.store_name,
    si18n.store_description,
    
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
    tl.last_date_config_theme

FROM store_base sb
LEFT JOIN store_i18n si18n ON sb.store_id = si18n.store_id
LEFT JOIN store_settings ss ON sb.store_id = ss.store_id
LEFT JOIN invoice_info ii ON sb.store_id = ii.store_id
LEFT JOIN main_user mu ON sb.store_id = mu.store_id AND sb.main_user_id = mu.user_id
LEFT JOIN theme_latest tl ON sb.store_id = tl.store_id AND tl.rn = 1

