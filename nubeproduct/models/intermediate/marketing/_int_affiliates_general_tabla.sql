-- Owner: YAN GERMANO
SELECT 
    SS.store_id,
    SC.created_at,
    SS.first_payment,
    SS.first_seller_at,
    SS.churned_at,
    SS.new_seller,
    SS.new_payment,
    SS.is_store_blocked,
    
    AP.is_quality_lead,

    SC.country_code,
    SC.partner_id
FROM {{ ref('s__lifecycle__store_status__ref') }} AS SS
LEFT JOIN {{ ref('s__attributes__store_core__ref') }} AS SC ON SS.store_id = SC.store_id
LEFT JOIN {{ ref('s__attributes__acquisition_profile__ref') }} AS AP ON SS.store_id = AP.store_id
WHERE SC.partnership_type = 'affiliate'