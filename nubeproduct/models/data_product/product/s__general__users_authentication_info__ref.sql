{{
    config(
        materialized='incremental',
        unique_key='user_id',
        incremental_strategy='merge',
        on_schema_change='fail', 
        tags=['daily-10am'] 
    )
}}

WITH base AS (
    SELECT
        *
    FROM {{ ref('_int__product__general__users_authentication_info') }}
),

existing_data AS (
    {{ get_existing_data(this, [
        'user_id', 
        'sys_audit_created_on', 
        'sys_audit_created_by'
    ]) }}
)

SELECT
    -- Keys and identifiers
    b.user_id
    ,b.store_id

    -- User attributes
    ,b.user_name
    ,b.user_email
    ,b.user_role
    ,b.nube_employee

    -- Registration and deletion dates
    ,b.user_registered_at
    ,b.user_deleted_at
    
    -- MFA status
    ,b.mfa_enabled
    ,b.mfa_deleted_at
    ,b.mfa_activated
    ,b.mfa_first_activation_date
    ,b.recovery_code_generated
    ,b.mfa_forced_date
    ,b.mfa_required

    -- Audit columns
    ,COALESCE(e.sys_audit_created_on, current_timestamp()) AS sys_audit_created_on
    ,COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
    ,current_timestamp() AS sys_audit_updated_on
    ,'data-dev-dbt-products' AS sys_audit_updated_by
FROM base b
LEFT JOIN existing_data e
    ON b.user_id = e.user_id