{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='dealbreaker_id',
        on_schema_change='fail'
    )
}}

-- product__general__hubspot_dealbreaker_company__link

WITH source_data AS (
    SELECT
        cast(dca.dealbreaker_id as bigint) as dealbreaker_id,
        dca.type as association_type,
        cast(dca.company_id as bigint) as company_id,
        TRUE AS is_present_in_source
    FROM {{ source('stg_hubspot','dealbreakers_companies_associations') }} dca
),

existing_data AS (
    {{ get_existing_data(this, ['dealbreaker_id', 'association_type', 'company_id', 'row_hash', 'sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
)

SELECT
 
    COALESCE(s.dealbreaker_id, e.dealbreaker_id) AS dealbreaker_id,
    COALESCE(s.association_type, e.association_type) AS association_type,
    CASE
        WHEN s.is_present_in_source IS NOT NULL THEN s.company_id
        ELSE NULL
    END AS company_id,
    md5(concat_ws('|',
        cast(COALESCE(s.dealbreaker_id, e.dealbreaker_id) as varchar(100)),
        COALESCE(s.association_type, e.association_type),
        cast(CASE WHEN s.is_present_in_source IS NOT NULL THEN s.company_id ELSE NULL END as varchar(100))
    )) AS row_hash, -- lo usamos para persistir correctamente los campos de auditoría
    
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
            OR md5(concat_ws('|', cast(COALESCE(s.dealbreaker_id, e.dealbreaker_id) as varchar(100)), COALESCE(s.association_type, e.association_type), cast(CASE WHEN s.is_present_in_source IS NOT NULL THEN s.company_id ELSE NULL END as varchar(100)))) <> e.row_hash
            THEN current_timestamp
        ELSE e.sys_audit_updated_on
    END AS sys_audit_updated_on,
    CASE
        WHEN e.dealbreaker_id IS NULL
            OR md5(concat_ws('|', cast(COALESCE(s.dealbreaker_id, e.dealbreaker_id) as varchar(100)), COALESCE(s.association_type, e.association_type), cast(CASE WHEN s.is_present_in_source IS NOT NULL THEN s.company_id ELSE NULL END as varchar(100)))) <> e.row_hash
            THEN 'data-dev-dbt-products'
        ELSE e.sys_audit_updated_by
    END AS sys_audit_updated_by

FROM source_data s
FULL OUTER JOIN existing_data e
    ON s.dealbreaker_id = e.dealbreaker_id
