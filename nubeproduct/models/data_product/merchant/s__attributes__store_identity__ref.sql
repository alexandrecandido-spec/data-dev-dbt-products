{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        on_schema_change = 'fail',
        tags=['daily-8am-8pm'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE store_id IN (SELECT store_id FROM {{ ref('merchant__attributes__store_info__ref') }} WHERE state = 4)"
        ]
    )
}}

/*
Data Product: Store Identity (SILVER REF)
Description: Información consolidada de identidad de la tienda (contactos, documentos, redes sociales, tema)
Owner: jhu.boggio@tiendanube.com
Domain: merchant

Este modelo consume desde el intermediate _int__attributes__store_identity que contiene toda la lógica
de consolidación de datos. Este modelo solo maneja la incrementalidad y los campos de auditoría.

✅ Materialización INCREMENTAL:
   - Procesa tiendas nuevas y existentes con cambios en información de identidad
   - Estrategia MERGE con unique_key=store_id
   - Actualiza registros cuando cambian datos de contacto, documentos, redes sociales o tema
*/

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source_data AS (
SELECT
    sid.store_id,
    sid.main_user_id,
    
    -- Información de la tienda
    sid.store_name,
    sid.store_description,
    
    -- Información de contacto
    sid.user_email,
    sid.user_first_name,
    sid.user_last_name,
    sid.user_nicename,
    sid.user_registered_at,
    sid.user_role,
    sid.phone_from_footer,
    sid.owner_phone_number,
    sid.phone_whatsapp_button,
    sid.owner_phone,
    
    -- Documentos fiscales
    sid.doc_type,
    sid.doc_number,
    
    -- Redes sociales
    sid.instagram,
    sid.facebook,
    sid.twitter,
    sid.tiktok,
    sid.pinterest,
    
    -- Facebook Pixel y CAPI
    sid.pixel_fb,
    sid.capi_status,
    
    -- 2FA Status
    sid.twofa_status,
    
    -- Social Ads (TikTok, Google Ads, Google MC, Google User)
    sid.tiktok_ads,
    sid.google_ads,
    sid.google_mc,
    sid.google_user,
    
    -- Tema
    sid.active_theme,
    sid.first_date_config_theme,
    sid.last_date_config_theme,
    
    -- Informacion de instalacion de APP nuvemshop/Tendanube
    sid.tiendanube_app_installed_at

FROM {{ ref('_int__attributes__store_identity') }} sid
WHERE
sid.state != 4
{% if not is_incremental() %}
  AND sid.change_timestamp >= DATE '1900-01-01'
{% endif %}
{% if is_incremental() %}
  AND sid.change_timestamp > ( SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }} )
{% endif %}
)

SELECT
    sd.*,
    -- Auditoría
    COALESCE(ed.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data sd
LEFT JOIN existing_data ed ON sd.store_id = ed.store_id