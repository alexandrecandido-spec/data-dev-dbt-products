SELECT 
    store_id,
    signup_status,
    CASE 
        WHEN signup_status = 'completed' 
        THEN unix_timestamp(updated_at) - unix_timestamp(created_at)
        ELSE NULL 
    END AS time_at_sign_up,
    sys_audit_updated_on
FROM {{ ref('product__onboarding__questionnaire_status__ref') }}  
