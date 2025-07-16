{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    cluster_by           = ['year_month_day_code','session_status'],
    unique_key           = ['row_hash'],
    on_schema_change     = 'fail',
    tags                 = ['daily-6am', 'marketing']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['row_hash', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

attribution_int AS (
  SELECT *
  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
  {% if is_incremental() %}
    WHERE year_month_day_code >= (
            SELECT COALESCE(MAX(year_month_day_code), 19000101)
            FROM existing_data
          )
      AND sys_audit_updated_on >= (
            SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
            FROM existing_data
          )
  {% else %}
    WHERE date >= DATE '2024-01-01'
  {% endif %}
),

final AS (
  SELECT
    sd.* EXCEPT(
      row_hash,
      sys_audit_created_on, sys_audit_created_by,
      sys_audit_updated_on, sys_audit_updated_by
    ),

    MD5(
      CONCAT_WS('|',
        CAST(sd.year_month_day_code AS STRING),
        CAST(sd.date                AS STRING),
        sd.source_ga4_classification,
        sd.original_user_country,
        sd.classified_country,
        sd.env,
        sd.landing_page,
        sd.landing_page_domain,
        sd.landing_page_path,
        sd.last_source,
        sd.last_medium,
        sd.last_campaign,
        sd.first_event_device,
        sd.last_event_device,
        CAST(sd.only_login_session  AS STRING),
        sd.user_type,
        sd.session_status,
        sd.utm_ad_id,
        sd.utm_content,
        sd.utm_term,
        sd.mkt_source,
        sd.mkt_subteam
      )
    )                                                  AS row_hash,

    COALESCE(e.sys_audit_created_on, current_timestamp)      AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp                                         AS sys_audit_updated_on,
    'data-dev-dbt-products'                                   AS sys_audit_updated_by

  FROM attribution_int sd
  LEFT JOIN existing_data e ON
    MD5(
      CONCAT_WS('|',
        CAST(sd.year_month_day_code AS STRING),
        CAST(sd.date                AS STRING),
        sd.source_ga4_classification,
        sd.original_user_country,
        sd.classified_country,
        sd.env,
        sd.landing_page,
        sd.landing_page_domain,
        sd.landing_page_path,
        sd.last_source,
        sd.last_medium,
        sd.last_campaign,
        sd.first_event_device,
        sd.last_event_device,
        CAST(sd.only_login_session  AS STRING),
        sd.user_type,
        sd.session_status,
        sd.utm_ad_id,
        sd.utm_content,
        sd.utm_term,
        sd.mkt_source,
        sd.mkt_subteam
      )
    ) = e.row_hash
)

SELECT * FROM final
