{{
    config(
        materialized='incremental',
        unique_key='store_id',
        on_schema_change='fail',
        tags=["operations","daily-8am-8pm"],
        post_hook=[
            "DELETE FROM {{ this }}
                    WHERE store_id IN (
                        SELECT id
                        FROM {{ source('stg_moltres', 'mwp_store_info') }}
                        WHERE state = 4 
            )"
            ]
    )
}}

-- gets stores that have 404 or 429 tags
WITH store_tags AS (
    SELECT 
        related_id AS store_id,
        MAX(sys_audit_updated_on) AS tag_last_updated_at
    FROM 
        {{ source('stg_moltres', 'mwp_tags') }}
    WHERE 
        type = 'store'
        AND tag IN ('sre-block-store-404', 'sre-block-store-429')
    GROUP BY 
        related_id
)

-- gets store information from mwp_store_info
, source AS (
    SELECT 
        id,
        state,
        country,
        current_segment,
        churned_at,
        created_at,
        first_payment,
        currency,
        plan,
        verified,
        register_url,
        main_user_id,
        partner_id,
        partnership_type,
        domain,
        CASE WHEN store_tags.store_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_store_blocked,
        custom_theme
    FROM {{ source('stg_moltres', 'mwp_store_info') }} AS msi
    LEFT JOIN 
        store_tags
        ON msi.id = store_tags.store_id
    WHERE 
        state != 4 
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    OR tag_last_updated_at >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    id as store_id,
    state, 
    country,
    currency,
    current_segment,
    first_payment,
    churned_at,
    created_at,
    plan, 
    verified, 
    register_url,
    main_user_id,
    partner_id, 
    partnership_type, 
    domain,
    is_store_blocked,
    custom_theme,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.id = e.store_id