{{ config(
    materialized = 'incremental',
    unique_key = 'unique_session_key',
    partition_by = 'base_date',
    on_schema_change = 'fail',
    tags = ['daily-9am-9pm']
) }}

WITH base_sessions_raw AS (
SELECT 
    scs.*
FROM
    {{ source('data_staging', 'storefronts_curated__sessions') }} AS scs
WHERE 
    {% if not is_incremental() %}
    scs.base_date BETWEEN DATE('2024-01-01') AND DATE('2024-01-05')
    {% else %}
    scs.base_date {{ get_max_date(this, 'base_date', 4, 'month') }}
    {% endif %}

    -- exclude: likely from merchants creating their own design
    AND ( 
        scs.http_referral LIKE '%conekta-tiendanube%'
        OR scs.http_referral LIKE '%stats.tiendanube.com%'
        OR scs.http_referral LIKE '%lojavirtualnuvem.com.br/admin%'
        OR scs.http_referral LIKE '%mitiendanube.com/admin%'
        OR scs.http_referral LIKE '%lojavirtualnuvem.com.br/?preview%'
        OR scs.http_referral LIKE '%mitiendanube.com/?preview%'
        OR scs.http_referral LIKE '%exit_preview_theme_installation%'
        OR scs.http_referral LIKE '%.my.canva.site%'
        OR (
           scs.http_referral IS NOT NULL
            AND scs.http_referral NOT LIKE 'http%'
            AND scs.http_referral NOT LIKE 'www%'
            AND scs.http_referral NOT LIKE 'android-app%'
            AND scs.http_referral NOT LIKE 'ios-app%'
            AND scs.http_referral NOT LIKE 'about:%'
            AND scs.http_referral NOT LIKE 'file:%'
            )
        )
)

, existing_data AS (
    {{ get_existing_data(this, ['unique_session_key', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    bsr.unique_session_key
    , bsr.session_timestamp
    , bsr.base_date
    , bsr.session_id
    , bsr.consumer_id
    , bsr.store_id
    , bsr.visitor_country
    , bsr.device
    , bsr.theme
    , bsr.user_agent
    , bsr.ip_address
    , bsr.utm_source
    , bsr.utm_medium
    , bsr.utm_campaign
    , bsr.utm_term
    , bsr.utm_content
    , bsr.landing_page
    , bsr.http_referral
    , COALESCE(existing_data.sys_audit_created_on, CURRENT_TIMESTAMP) AS sys_audit_created_on
    , COALESCE(existing_data.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM 
    base_sessions_raw AS bsr
LEFT JOIN 
    existing_data 
    ON bsr.unique_session_key = existing_data.unique_session_key
