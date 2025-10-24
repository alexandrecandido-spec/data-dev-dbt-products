-- Brings sessions with enriched UTMs, user classification and traffic classification. SSOT

{{ config(
   materialized = 'incremental',
   unique_key = 'unique_session_key',
   partition_by = 'base_date',
   on_schema_change = 'fail',
   tags = ['product', 'daily-3am']
) }}

WITH swd AS (
SELECT
    *
FROM
    {{ ref('_int_product__session_with_domains') }}
WHERE
   {% if not is_incremental() %}
   base_date BETWEEN DATE('2024-01-01') AND DATE('2024-01-05')
   {% else %}
   base_date {{ get_max_date(this, 'base_date', 1, 'month') }}
   {% endif %}
)

, stc AS (
SELECT
    *
FROM
    {{ ref('_int_product__session_traffic_classification')}}
WHERE
   {% if not is_incremental() %}
   base_date BETWEEN DATE('2024-01-01') AND DATE('2024-01-05')
   {% else %}
   base_date {{ get_max_date(this, 'base_date', 1, 'month') }}
   {% endif %}
)

, suc AS (
SELECT
    *
FROM
    {{ ref('_int_product__session_user_classification') }}
WHERE
   {% if not is_incremental() %}
   base_date BETWEEN DATE('2024-01-01') AND DATE('2024-01-05')
   {% else %}
   base_date {{ get_max_date(this, 'base_date', 1, 'month') }}
   {% endif %}
)

, raw_sessions AS (
SELECT
   swd.unique_session_key
   , swd.session_timestamp
   , swd.base_date
   , swd.session_id
   , swd.consumer_id
   , swd.store_id
   , swd.visitor_country
   , swd.device
   , swd.theme
   , swd.user_agent
   , swd.ip_address
   , swd.utm_source
   , swd.utm_medium
   , swd.utm_campaign
   , swd.utm_term
   , swd.utm_content
   , swd.landing_page
   , swd.http_referral
   , swd.ref_domain
   , swd.land_domain
   , stc.source_name
   , stc.source_group
   , stc.google_subchannel
   , stc.traffic_type
   , COALESCE(suc.is_end_user, TRUE) AS is_end_user
FROM
   swd
LEFT JOIN
   stc
   ON swd.unique_session_key = stc.unique_session_key
LEFT JOIN
   suc
   ON swd.unique_session_key = suc.unique_session_key
)

, existing_data AS (
   {{ get_existing_data(this, ['unique_session_key', 'sys_audit_created_on', 'sys_audit_created_by'])}}
)

SELECT
   raw_sessions.unique_session_key
   , raw_sessions.session_timestamp
   , raw_sessions.base_date
   , raw_sessions.session_id
   , raw_sessions.consumer_id
   , raw_sessions.store_id
   , raw_sessions.visitor_country
   , raw_sessions.device
   , raw_sessions.theme
   , raw_sessions.user_agent
   , raw_sessions.ip_address
   , raw_sessions.utm_source
   , raw_sessions.utm_medium
   , raw_sessions.utm_campaign
   , raw_sessions.utm_term
   , raw_sessions.utm_content
   , raw_sessions.landing_page
   , raw_sessions.http_referral
   , raw_sessions.ref_domain
   , raw_sessions.land_domain
   , raw_sessions.source_name
   , raw_sessions.source_group
   , raw_sessions.google_subchannel
   , raw_sessions.traffic_type
   , raw_sessions.is_end_user
   , COALESCE(existing_data.sys_audit_created_on, CURRENT_TIMESTAMP) AS sys_audit_created_on
   , COALESCE(existing_data.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
   , CURRENT_TIMESTAMP AS sys_audit_updated_on
   , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
   raw_sessions
LEFT JOIN
   existing_data
   ON raw_sessions.unique_session_key = existing_data.unique_session_key