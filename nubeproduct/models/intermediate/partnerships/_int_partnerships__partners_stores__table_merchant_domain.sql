WITH partners_stores AS
(
    SELECT 
        SC.store_id,
        SC.domain,
        SI.main_user_id,
        SI.store_name,
        SI.user_email,
        SI.owner_phone,
        SI.phone_whatsapp_button,
        SI.doc_type,
        SI.doc_number,
        SC.created_at,
        SC.country_code,
        SC.country_name,
        SC.currency,
        SC.partner_id,
        SC.partnership_type,
        PI.partner_country_code,
        SC.vertical_name,
        SS.first_payment,
        SS.churned_at,
        SS.first_seller_at,
        SS.new_seller,
        SS.current_plan_id,
        SS.current_plan_type,
        SS.current_plan_name,
        SS.is_seller,
        SS.is_store_blocked,
        SS.new_payment,
        SS.state,
        SS.current_segment,
        AP.tag_acquired_by,
        AP.is_quality_lead,
        IF(SS.current_plan_type = 'enterprise','MM','SMB') AS business_unit,
        IF(SS.churned_at IS NOT NULL, TRUE, FALSE) AS churned_flg,
        CASE 
            WHEN SS.first_payment IS NOT NULL 
                AND SS.churned_at IS NULL
                AND SS.current_plan_type != 'freemium'    
            THEN 'Paying'    
            WHEN SS.churned_at IS NOT NULL
            THEN 'Churned'     
            WHEN SS.current_plan_type = 'freemium'   
            THEN 'Freemium'
        ELSE 'Trial'
        END AS payment_lifecycle_status
    FROM {{ ref('s__attributes__store_core__ref') }} AS SC
    LEFT JOIN {{ ref('s__lifecycle__store_status__ref') }} AS SS
        ON SC.store_id = SS.store_id
    LEFT JOIN {{ ref('s__attributes__acquisition_profile__ref') }} AS AP
        ON SC.store_id = AP.store_id
    LEFT JOIN {{ ref('s__attributes__store_identity__ref') }} AS SI
        ON SC.store_id = SI.store_id
    LEFT JOIN {{ ref('s__general__partners_info__ref') }} AS PI 
        ON SC.partner_id = PI.partner_id
    WHERE SC.partner_id IS NOT NULL
)
SELECT * FROM partners_stores