{{ config(
    materialized = 'incremental',
    unique_key = ['row_key'],
    partition_by = ['year_month_day_code'],
    on_schema_change = 'fail',
    tags = ['daily-11am']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, [ 'row_key', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
main_source as (
SELECT 
    *,
    CAST(DATE_FORMAT(DATE, 'yyyyMMdd') as INTEGER) AS year_month_day_code,
    lower(
      hex(
        md5(
          concat_ws(
            '|',
            cast(store_id as varchar(30)),
            cast(date as varchar(30)),
            cast(country_code as varchar(30)),
            coalesce(source, ''),
            coalesce(medium, ''),
            coalesce(campaign, ''),
            coalesce(content, ''),
            coalesce(http_referrer, ''),
            coalesce(landing_page, ''),
            coalesce(device, ''),
            coalesce(tipo, ''),
            coalesce(status, ''),
            coalesce(flux, ''),
            coalesce(email_name, '')
          )
        )
      )
    ) as row_key,
    MAX(change_timestamp) as max_change_timestamp
FROM {{ ref('_int__acquisition__nurturing_growth_metrics') }}
GROUP BY ALL 
)
SELECT
  main_source.*,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM main_source 
LEFT JOIN existing_data e ON main_source.row_key = e.row_key

WHERE 
{% if not is_incremental() %}
      main_source.date >= DATE '2024-01-01'
    {% endif %}
{% if is_incremental() %}
      main_source.max_change_timestamp > (
        SELECT COALESCE(MAX(sys_audit_updated_on) - INTERVAL 1 DAY, DATE '1900-01-01')
        FROM {{ this }}
      )
    {% endif %}