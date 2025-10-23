SELECT
    sp.store_id AS store_id,
    sp.free_text AS free_text,
    dm.group_code AS group_code,
    dt.description AS description
FROM {{ ref('product__onboarding__store_preferences__event') }} AS sp
LEFT JOIN {{ ref('product__onboarding__domain_mappings__ref') }} AS dm
    ON dm.id = sp.domain_mapping_id
LEFT JOIN {{ ref('product__onboarding__domain_types__ref') }} AS dt
    ON dm.type_code = dt.code


