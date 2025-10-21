{{
    config(
        materialized='incremental',
        unique_key='store_id',
        on_schema_change='fail',
        tags=["merchant","daily-8am-8pm"]
    )
}}

-- gets store information from mwp_store_info
WITH source AS (
    SELECT 
        id,
        domain,
        state,
        country,
        currency,
        current_segment,
        created_at,
        first_payment,
        churned_at,
        plan,
        paid_until,
        verified,
        register_url,
        main_user_id,
        partner_id,
        partnership_type,
        disabled,
        custom_theme
    FROM {{ source('stg_moltres', 'mwp_store_info') }} AS msi
    WHERE 
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% else %}
        1 = 1 -- this will always be true if not incremental
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    id as store_id,
    domain,
    state, 
    country,
    currency,
    current_segment,
    created_at,
    first_payment,
    churned_at,
    plan,
    paid_until,
    verified, 
    register_url,
    main_user_id,
    partner_id, 
    partnership_type, 
    disabled,
    custom_theme,
    current_date() AS date_ref,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.id = e.store_id