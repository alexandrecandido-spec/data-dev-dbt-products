{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key='partner_event_hash_key',
  on_schema_change='fail',
  tags=['daily-8am','marketing']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['partner_event_hash_key', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT DISTINCT 
    md5(concat_ws(
        '-',
        coalesce(P.partner_code, ''),
        coalesce(GA4.event_date, ''),
        coalesce(GA4.event_source, ''),
        coalesce(GA4.country, ''),
        coalesce(GA4.source, ''),
        coalesce(GA4.event_medium, ''),
        coalesce(GA4.event_campaign, ''),
        coalesce(GA4.landing_page, ''),
        coalesce(GA4.page, '')
    )) as partner_event_hash_key,

    -- Partner Data
    P.partner_name,
    P.partner_code,
    P.partner_country_code,
    P.affiliate_classification,
    P.affiliate_tier,
    P.affiliate_main_platform,

    -- GA4 Data
    GA4.event_date,
    GA4.country,
    GA4.source,
    GA4.event_source,
    GA4.event_medium,
    GA4.event_campaign,
    GA4.event_content,
    GA4.landing_page,
    GA4.page,

    -- Aggregated Data
    COUNT(DISTINCT GA4.user_pseudo_id) AS total_users,
    COUNT(DISTINCT GA4.unique_session) AS total_sessions,

    -- Audit Data
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('s__general__partners_info__ref') }} AS P 
LEFT JOIN {{ ref('_int_marketing__ga4_affiliates') }} AS GA4 
       ON P.partner_code = GA4.partner_code
LEFT JOIN existing_data AS e 
       ON md5(concat(coalesce(cast(P.partner_code as string), ''), '-', coalesce(cast(GA4.event_date as string), ''))) = e.partner_event_hash_key

WHERE 1=1
{% if not is_incremental() %}
    AND GA4.event_date >= DATE '1900-01-01'
{% else %}
    AND GA4.event_date >= (
        SELECT COALESCE(MAX(event_date), DATE '1900-01-01') 
        FROM {{ this }}
    )
{% endif %}

GROUP BY
    P.partner_name,
    P.partner_code,
    P.partner_country_code,
    P.affiliate_classification,
    P.affiliate_tier,
    P.affiliate_main_platform,
    GA4.event_date,
    GA4.country,
    GA4.source,
    GA4.event_source,
    GA4.event_medium,
    GA4.event_campaign,
    GA4.event_content,
    GA4.landing_page,
    GA4.page
