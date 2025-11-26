{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  partition_by='year_month_day_code',
  unique_key=['row_hash'],
  on_schema_change='fail',
  tags=['daily-8am'],
  pre_hook = [
      "
      {% if is_incremental() %}
        -- Safety net: Reload last 5 days to handle GSC latency
        MERGE INTO {{ this }} AS t
        USING (
          SELECT DISTINCT CAST(date_format(d, 'yyyyMMdd') AS INT) as year_month_day_code
          FROM (
             SELECT explode(sequence(date_sub(current_date(), 5), current_date())) as d
          )
        ) AS s
        ON t.year_month_day_code = s.year_month_day_code
        WHEN MATCHED THEN DELETE;
      {% endif %}
      "
    ]
) }}

{% if is_incremental() %}
-- Get last update timestamp to detect changes in classification inputs
WITH last_upd AS (
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS max_upd FROM {{ this }}
),
-- Last 5 days for mandatory reload
base_days AS (
  SELECT CAST(date_format(d,'yyyyMMdd') AS INT) AS dc
  FROM (SELECT explode(sequence(date_sub(current_date(), 5), current_date())) as d)
)
{% endif %}

-- 1. Source: Classified Intermediate
, main_source AS (
    SELECT * FROM {{ ref('_int__marketing__gsc_url_results_classified') }}
    {% if not is_incremental() %}
    WHERE date >= DATE '2024-01-01' -- Historical load
    {% endif %}
)

-- 2. Intelligent Incremental Filter
, candidate_rows AS (
  SELECT main_source.*
  FROM main_source
  {% if is_incremental() %}
  WHERE
     -- A. Recent time window
     main_source.year_month_day_code IN (SELECT dc FROM base_days)
     -- B. Or old rows where classification changed (Input Updated -> Hash changed)
     OR main_source.change_timestamp_incremental >= (SELECT max_upd FROM last_upd)
  {% endif %}
)

/* 3. Final Selection */
SELECT
    -- Temporal Dimensions
    c.year_month_day_code,
    c.date,
    
    -- GSC Dimensions
    c.full_url,
    c.path,
    c.search_type,
    c.country_name,
    c.device,
    
    -- Metrics (Corrected by Unsplit logic)
    c.impressions,
    c.clicks,
    c.average_position,
    
    -- NEW Classifications (Genkidama)
    c.page_group,        
    c.page_subgroup,     
    c.classified_country,
    
    -- Incremental Audit
    c.input_sources AS dp_input_sources,
    c.change_timestamp_incremental AS dp_change_timestamp_incremental,
    c.row_hash,
    
    -- System Audit
    CAST(current_timestamp AS TIMESTAMP) AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    CAST(current_timestamp AS TIMESTAMP) AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM candidate_rows c