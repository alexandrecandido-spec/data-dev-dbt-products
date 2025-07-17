SELECT 
    id AS partner_id,
    code AS partner_code,
    name AS partner_name, 
    MC.country_code AS partner_country_code,
    created_at AS partner_created_at_ts,
    email AS partner_email,
    phone_number AS partner_phone_number
FROM {{ source('int_ecosystem', 'mwp_partners') }} AS MP
LEFT JOIN 
    (
        SELECT DISTINCT
            id AS country_id,
            code AS country_code,
            name_en AS country_name
        FROM {{ source('int_moltres', 'mwp_countries') }} 
    ) AS MC
    ON MP.country = MC.country_id