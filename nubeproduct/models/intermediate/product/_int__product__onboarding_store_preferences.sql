SELECT
    sp.store_id AS store_id,
    replace(dm.group_code,  '_' || split_part(dm.group_code, '_', -1),'') AS group_code,
    dt.description AS description,
    sp.free_text AS free_text    
FROM {{ ref('product__onboarding__store_preferences__event') }} AS sp
LEFT JOIN {{ source('int_onboarding', 'domain_mappings') }} AS dm
    ON dm.id = sp.domain_mapping_id
LEFT JOIN {{ source('int_onboarding', 'domain_types') }} AS dt 
    ON dm.type_code = dt.code