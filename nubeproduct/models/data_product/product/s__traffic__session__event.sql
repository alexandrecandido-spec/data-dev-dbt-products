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
   base_date {{ get_max_date(this, 'base_date', 2, 'week') }}
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
   base_date {{ get_max_date(this, 'base_date', 2, 'week') }}
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
   base_date {{ get_max_date(this, 'base_date', 2, 'week') }}
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
   AND swd.base_date = stc.base_date
LEFT JOIN
   suc
   ON swd.unique_session_key = suc.unique_session_key
   AND swd.base_date = suc.base_date
)

, deduped_sessions AS (
SELECT
    *
FROM (
    SELECT
        *
        , ROW_NUMBER() OVER (PARTITION BY unique_session_key ORDER BY session_timestamp ASC) AS row_num
    FROM raw_sessions
) sub
WHERE row_num = 1
)

, existing_data AS (
    {{ get_existing_data(this, ['unique_session_key'])}}
)

SELECT
   dds.unique_session_key
   , dds.session_timestamp
   , dds.base_date
   , dds.session_id
   , dds.consumer_id
   , dds.store_id
   , dds.visitor_country
   , dds.device
   , dds.theme
   , dds.user_agent
   , dds.ip_address
   , dds.utm_source
   , dds.utm_medium
   , dds.utm_campaign
   , dds.utm_term
   , dds.utm_content
   , dds.landing_page
   , dds.http_referral
   , dds.ref_domain
   , dds.land_domain
   , dds.source_name
   , dds.source_group
   , dds.google_subchannel
   , dds.traffic_type
   , dds.is_end_user
    , CURRENT_TIMESTAMP AS sys_audit_created_on
    , 'data-dev-dbt-products' AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
   deduped_sessions AS dds
LEFT JOIN
   existing_data
   ON dds.unique_session_key = existing_data.unique_session_key
WHERE
    existing_data.unique_session_key IS NULL