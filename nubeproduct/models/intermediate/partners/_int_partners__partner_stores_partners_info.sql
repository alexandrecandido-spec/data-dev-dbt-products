SELECT 
    id AS partner_id,
    code AS partner_code,
    name AS partner_name, 
    MC.country_code AS partner_country_code,
    created_at AS partner_created_at_ts,
    AC.affiliate_classification,    
    AC.affiliate_tier,
    AC.affiliate_main_platform, 
    AC.mkt_exclusion
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
LEFT JOIN {{ ref('_int_partners__partner_stores_affiliates_classification') }} AS AC
    ON MP.code = AC.partner_code
        AND MP.country = AC.affiliate_country