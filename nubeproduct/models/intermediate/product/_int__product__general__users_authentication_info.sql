-- Intermediate model that consolidates Multi Factor Authentication (mfa) information of all users (not only the main users)

WITH mfa_totp_users AS (
    SELECT 
        CAST(user_id AS STRING) AS user_id
        ,enabled AS mfa_enabled
        ,CAST(deleted_at AS DATE) AS mfa_deleted_at
    FROM {{ source('int_newadmin', 'authentication_factors') }}
    WHERE type = 'TOTP'
),

first_mfa_activation AS (
    SELECT 
        CAST(userId AS STRING) AS user_id
        ,MIN(CAST(createdAt AS DATE)) AS mfa_first_activation_date
    FROM {{ source('int_newadmin', 'authentication_log') }}
    WHERE userId IN (
        SELECT DISTINCT
            CAST(user_id AS STRING) AS user_id
        FROM {{ source('int_newadmin', 'authentication_factors') }}
        WHERE type = 'TOTP' AND enabled = 1
    )
    GROUP BY user_id
),

recovery_codes_active AS (
    SELECT 
        CAST(user_id AS STRING) AS user_id
    FROM {{ source('int_newadmin', 'authentication_factors') }}
    WHERE 
        type = 'RECOVERY_CODE'
        AND enabled = 1
        AND deleted_at IS NULL 
),

-- store_id level
mfa_forced_stores AS (
    SELECT 
        CAST(store_id AS STRING) AS store_id 
        ,CAST(deadline AS DATE) AS mfa_forced_date
        ,required AS mfa_required
    FROM {{ source('int_newadmin', 'security_requirements') }}
    WHERE type = '2fa' AND required = 1
)

SELECT DISTINCT 
    CAST(wu.id AS STRING) AS user_id
    ,concat(wu.first_name, ' ', wu.last_name) AS user_name
    ,wu.user_email
    ,wu.role AS user_role
    ,wu.user_registered AS user_registered_at
    ,wu.deleted AS user_deleted_at
    ,CAST(wu.store_id AS STRING) 
    ,CASE WHEN wu.store_id IS NULL THEN TRUE ELSE FALSE END AS nube_employee
    ,CASE WHEN totp.mfa_enabled = 1 THEN TRUE ELSE FALSE END AS mfa_enabled
    ,totp.mfa_deleted_at
    ,CASE WHEN (totp.mfa_enabled = 1 AND totp.mfa_deleted_at IS NULL) THEN TRUE ELSE FALSE END AS mfa_activated
    ,fmfa.mfa_first_activation_date
    ,CASE WHEN rca.user_id IS NULL THEN FALSE ELSE TRUE END AS recovery_code_generated
    ,mfs.mfa_forced_date
    ,CASE WHEN mfs.mfa_required = 1 THEN TRUE ELSE FALSE END AS mfa_required
FROM {{ source('int_moltres','wp_users') }} AS wu
LEFT JOIN mfa_totp_users AS totp 
    ON totp.user_id = wu.id
LEFT JOIN first_mfa_activation AS fmfa 
    ON fmfa.user_id = wu.id
LEFT JOIN recovery_codes_active AS rca 
    ON rca.user_id = wu.id
LEFT JOIN mfa_forced_stores AS mfs 
    ON mfs.store_id = wu.store_id