SELECT 
    SS.store_id,
    SC.created_at,
    SS.first_payment,
    SS.first_seller_at,
    SS.churned_at,
    SS.new_seller,
    
    SC.country_code,
    SC.partner_id
FROM {{ ref('s__lifecycle__store_status__ref') }} AS SS
LEFT JOIN {{ ref('s__attributes__store_core__ref') }} AS SC ON SS.store_id = SC.store_id
WHERE SC.partnership_type = 'affiliate'