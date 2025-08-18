{{ config(
  materialized = 'incremental',
  incremental_strategy = 'merge',
  unique_key=['id'],
  on_schema_change='fail',
  tags=['daily-9am'],
  post_hook=[
            """
            DELETE FROM {{ this }}
            WHERE id IN (
              SELECT id
              FROM {{ ref('marketing_inputs_attribution') }}
              WHERE state = 'closed'
              )
            """
            ]
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
source AS (
  SELECT				
    ai.id
    , ai.input_number
    , ai.input_title
    , ai.input_type
    , ai.state
    , ai.affiliate_code	
    , ai.affiliate_country
    , ai.affiliate_tier
    , MIN(ai.affiliate_classification) OVER (PARTITION BY ai.affiliate_code) AS affiliate_classification
    , ai.created_at
    , ai.updated_at
    , ai.closed_at
    , COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
    , COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    , current_timestamp AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by
    , ROW_NUMBER() OVER (PARTITION BY ai.affiliate_code ORDER BY ai.affiliate_classification  ASC) AS rownumber						
  FROM {{ ref('marketing_inputs_attribution') }} ai	
  --Includes only records associated with affiliate classification
  LEFT JOIN existing_data e ON ai.id = e.id                      
  WHERE
      {% if not is_incremental() %}
        ai.created_at >= DATE '2025-01-01'
      {% endif %}
      {% if is_incremental() %}
        ai.sys_audit_updated_on > (
          SELECT COALESCE(MAX(sys_audit_created_on) - INTERVAL 1 DAY, DATE '1900-01-01')
          FROM {{ this }}
        )
      {% endif %}		
  AND ai.input_type = 'AFFILIATE_LIST'
  AND ai.state = 'open'		
)	

SELECT *
FROM source
WHERE rownumber = 1