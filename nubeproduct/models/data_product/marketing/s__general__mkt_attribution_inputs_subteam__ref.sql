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
              FROM {{ ref('s__general__mkt_attribution_inputs_all__ref') }}
              WHERE state = 'closed'
              )
            """
            ]
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT				
    ai.id
    , ai.input_number
    , ai.input_title
    , ai.input_type
    , ai.state
    , ai.utm_source			
    , ai.utm_medium
    , ai.utm_campaign							
    , ai.utm_content				
    , ai.team				
    , ai.subteam
    , ai.created_at
    , ai.updated_at
    , ai.closed_at
    , COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
    , COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    , current_timestamp AS sys_audit_updated_on
    , 'data-dev-dbt-products' AS sys_audit_updated_by			
FROM {{ ref('s__general__mkt_attribution_inputs_all__ref') }} ai					
--Includes only records associated with subteams
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
AND ai.input_type = 'SUBTEAM_MKT'			
AND ai.state = 'open'