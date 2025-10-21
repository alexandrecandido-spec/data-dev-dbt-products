{{
    config(
        materialized='incremental',
        unique_key= 'store_id',
        on_schema_change='fail',
        tags=['daily-9am']
    )
}}

WITH store_info AS (
    SELECT
        store_id, 
        created_at
    FROM
        {{ ref('moltres__mwp_store_info') }}
    WHERE is_store_blocked IS FALSE
    
    {% if is_incremental() %}
    AND sys_audit_updated_on >= (select coalesce(DATE_SUB(max(sys_audit_updated_on), 1), '1900-01-01') from {{ this }} )
    {% else %}
    AND DATE(created_at) >= add_months(current_date(), -12)
    {% endif %}
),

onboarding_types AS (
    SELECT
        store_id,
        onb_type_online,
        onb_type_offline,
        onb_type_chat
    FROM
        {{ ref('_int_onboarding_type') }}
),

source AS (
    SELECT
        si.store_id,
        si.created_at,
        CASE 
            WHEN ot.onb_type_offline >= 1 AND ot.onb_type_online = 0 AND ot.onb_type_chat = 0 THEN 'PDV'
            WHEN ot.onb_type_offline >= 1 AND ot.onb_type_online >= 1 AND ot.onb_type_chat = 0 THEN 'PDV + Online'
            WHEN ot.onb_type_offline = 0 AND ot.onb_type_online = 0 AND ot.onb_type_chat >= 1 THEN 'Chat'
            WHEN ot.onb_type_offline >= 1 AND ot.onb_type_online = 0 AND ot.onb_type_chat >= 1 THEN 'PDV + Chat'
            ELSE 'Online'
        END AS onboarding_type
    FROM
        store_info AS si
    LEFT JOIN
        onboarding_types AS ot
        ON si.store_id = ot.store_id
),

existing_data AS (
    {{ get_existing_data(this, ['store_id', 'created_at', 'onboarding_type', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    a.store_id,
    a.created_at,
    a.onboarding_type,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source a
LEFT JOIN existing_data e ON a.store_id = e.store_id and a.onboarding_type = e.onboarding_type



    