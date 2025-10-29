{{
    config(
        materialized='incremental',
        incremental_strategy = 'merge',
        unique_key='store_id',
        on_schema_change='fail',
        tags=["merchant","daily-8am"],
        post_hook=[
            "DELETE FROM {{ this }}
                    WHERE store_id NOT IN (
                        SELECT 
                            distinct related_id
                        FROM 
                            {{ source('stg_moltres', 'mwp_tags') }}
                        WHERE 
                            type = 'store'
                            AND tag IN ('sre-block-store-404', 'sre-block-store-429')
                            )"
            ]
    )
}}


-- gets stores that have 404 or 429 tags
WITH source_data AS (
    SELECT 
        related_id AS store_id,
        MAX(case when tag in ('sre-block-store-404', 'sre-block-store-429') then sys_audit_updated_on else null end) AS blocked_last_updated_at,
        MAX(case when tag in ('partner', 'channels-affiliate-attribution') then sys_audit_updated_on else null end) AS partner_last_updated_at,
        MAX(CASE WHEN tag = 'partner' THEN 1 ELSE 0 END) AS has_partner_tag,
        MAX(CASE WHEN tag = 'channels-affiliate-attribution' THEN 1 ELSE 0 END) AS has_affiliate_tag,
        MIN(case when tag in ('sre-block-store-404', 'sre-block-store-429') then sys_audit_created_on else null end) AS blocked_at,
        MAX(CASE WHEN tag IN ('sre-block-store-404', 'sre-block-store-429') THEN tag ELSE null END) AS blocked_reason
    FROM 
        {{ source('stg_moltres', 'mwp_tags') }}
    WHERE 
        type = 'store'
        AND tag IN ('sre-block-store-404', 'sre-block-store-429','partner', 'channels-affiliate-attribution')
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
    GROUP BY 
        related_id
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    sd.store_id,
    sd.blocked_last_updated_at,
    sd.partner_last_updated_at,
    sd.has_partner_tag,
    sd.has_affiliate_tag,
    sd.blocked_at,
    sd.blocked_reason,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data sd
LEFT JOIN existing_data e ON sd.store_id = e.store_id