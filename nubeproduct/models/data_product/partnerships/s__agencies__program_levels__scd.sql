{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'append',
        unique_key = ['partner_id','snapshot_date'],
        on_schema_change = 'fail',
        tags = ['monthly-1st-12AM']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['partner_id', 'snapshot_date', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
program_levels AS
(
    SELECT
        partner_id,
        snapshot_date,
        year_id,
        quarter_id,
        active_paying_stores,
        new_payments_last_quarter,
        new_payments_last_365d,
        partner_level_raw,
        raw_rank,
        partner_level,
        smooth_rank
    FROM {{ ref('_int_partnerships__partners_levels__smooth') }}
)
SELECT 
    PL.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM program_levels AS PL
LEFT JOIN existing_data AS e
    ON PL.partner_id = e.partner_id
    AND PL.snapshot_date = e.snapshot_date
    {% if is_incremental() %}
WHERE    
      PL.snapshot_date > 
        (
            SELECT COALESCE(MAX(snapshot_date), DATE '1900-01-01')
            FROM {{ this }}
        )
    {% endif %}
;