{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['operations','daily-6am']
) }}

with 
    source as (
        SELECT 
            da.id as deal_id,
            da.archivedAt as archived_at,
            da.updatedAt,
            da.createdAt
        FROM {{ source('stg_hubspot', 'deals_archived') }} as da
            {% if is_incremental() %}
            WHERE
            -- this filter will only be applied on an incremental run
            -- (uses >= to include records whose timestamp occurred since the last run of this model)
            -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
            da.updatedAt >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
            {% endif %}
    ),
    existing_data AS (
        {{ get_existing_data(this, ['deal_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
    )

SELECT 
    source.deal_id,
    'archived' as deletion_type,
    source.archived_at,
    source.updatedAt,
    source.createdAt,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
    LEFT JOIN existing_data e
        ON source.deal_id = e.deal_id