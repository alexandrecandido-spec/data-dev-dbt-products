{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='dealbreaker_id',
        on_schema_change='fail'
    )
}}

-- product__general__hubspot_dealbreaker_current__snapshot_daily

WITH source_data AS (
    SELECT
        cast(dba.id as bigint) as dealbreaker_id, -- lo casteo porque viene como string
        cast(dba.updatedAt as timestamp) as record_updated_at, -- lo casteo porque viene como string
        md5(concat_ws('|',
            cast(dba.id as varchar(100)),
            cast(dba.updatedAt as varchar(100))
        )) as row_hash, -- lo usamos para persistir correctamente los campos de auditoría
        TRUE AS is_current
    FROM {{ source('stg_hubspot','dealbreakers_base_association') }} dba
),

existing_data AS (
    {{ get_existing_data(this, ['dealbreaker_id', 'row_hash', 'is_current', 'sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
)

SELECT

    COALESCE(s.dealbreaker_id, e.dealbreaker_id) AS dealbreaker_id,
    s.record_updated_at,
    s.row_hash, -- lo usamos para persistir correctamente los campos de auditoría
    COALESCE(s.is_current, FALSE) AS is_current,
    
    CASE
        WHEN e.dealbreaker_id IS NULL THEN current_timestamp
        ELSE e.sys_audit_created_on
    END AS sys_audit_created_on,
    CASE
        WHEN e.dealbreaker_id IS NULL THEN 'data-dev-dbt-products'
        ELSE e.sys_audit_created_by
    END AS sys_audit_created_by,
    CASE
        WHEN e.dealbreaker_id IS NULL
            OR s.row_hash <> e.row_hash
            OR s.dealbreaker_id IS NULL
            THEN current_timestamp
        ELSE e.sys_audit_updated_on
    END AS sys_audit_updated_on,
    CASE
        WHEN e.dealbreaker_id IS NULL
            OR s.row_hash <> e.row_hash
            OR s.dealbreaker_id IS NULL
            THEN 'data-dev-dbt-products'
        ELSE e.sys_audit_updated_by
    END AS sys_audit_updated_by

FROM source_data s
FULL OUTER JOIN existing_data e
    ON s.dealbreaker_id = e.dealbreaker_id
