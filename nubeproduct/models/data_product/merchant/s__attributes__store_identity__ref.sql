{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='store_id',
        tags=['daily_7am']
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

-- Consumir datos consolidados desde el intermediate
store_identity_data AS (
    SELECT *
    FROM {{ ref('_int__attributes__store_identity') }}
)

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
    
    -- Tema
    sid.active_theme,
    sid.first_date_config_theme,
    sid.last_date_config_theme,
    
    -- Auditoría
    COALESCE(ed.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(ed.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM store_identity_data sid
LEFT JOIN existing_data ed ON sid.store_id = ed.store_id
{% if is_incremental() %}
    -- Procesar todas las tiendas (nuevas y existentes)
    -- MERGE actualizará solo los registros que realmente cambiaron
    -- No aplicamos filtro adicional para permitir actualización de tiendas existentes
{% endif %}

