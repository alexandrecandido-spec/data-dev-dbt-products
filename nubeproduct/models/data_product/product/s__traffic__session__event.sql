-- Brings sessions with enriched UTMs, user classification and traffic classification. SSOT

{{ config(
   materialized = 'incremental',
   unique_key = ['base_date', 'unique_session_key'],
   partition_by = 'base_date',
   on_schema_change = 'fail',
   tags = ['product', 'daily-3am'],
   pre_hook = [
        "DELETE FROM {{ this }} WHERE base_date = DATE('2024-09-23')"
    ]
) }}

{% set base_date_filter %}
  {% if 1 == 1 %}
    = DATE('2024-09-23')
  {% else %}
    {% if not is_incremental() %}
        BETWEEN DATE('2024-01-01') AND DATE('2024-01-05')
    {% else %}
        {{ get_max_date(this, 'base_date', 2, 'week') }}
    {% endif %}
  {% endif %}
{% endset %}

{% set base_date_filter = base_date_filter | replace('\n',' ') | replace('\t',' ') | trim %}

WITH swd AS (
SELECT
    *
FROM
    {{ ref('_int_product__session_with_domains') }}
WHERE
   base_date {{ base_date_filter }}
)

, stc AS (
SELECT
    *
FROM
    {{ ref('_int_product__session_traffic_classification')}}
WHERE
   base_date {{ base_date_filter }}
)

, suc AS (
SELECT
    *
FROM
    {{ ref('_int_product__session_user_classification') }}
WHERE
   base_date {{ base_date_filter }}
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

, existing_data as (
    {{ get_existing_data_where(
         this,
         ['base_date','unique_session_key'],
         "base_date " ~ base_date_filter
    ) }}
)

SELECT
    unique_session_key
    , session_timestamp
    , base_date
    , session_id
    , consumer_id
    , store_id
    , visitor_country
    , device
    , theme
    , user_agent
    , ip_address
    , utm_source
    , utm_medium
    , utm_campaign
    , utm_term
    , utm_content
    , landing_page
    , http_referral
    , ref_domain
    , land_domain
    , source_name
    , source_group
    , google_subchannel
    , traffic_type
    , is_end_user
    , CURRENT_TIMESTAMP AS sys_audit_created_on
    , 'data-dev-dbt-products' AS sys_audit_created_by
    , CURRENT_TIMESTAMP AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
FROM
   deduped_sessions AS dds
LEFT JOIN
   existing_data
   ON dds.unique_session_key = existing_data.unique_session_key
   AND dds.base_date = existing_data.base_date
WHERE
    existing_data.unique_session_key IS NULL
AND existing_data.base_date IS NULL
AND dds.base_date {{ base_date_filter }}
