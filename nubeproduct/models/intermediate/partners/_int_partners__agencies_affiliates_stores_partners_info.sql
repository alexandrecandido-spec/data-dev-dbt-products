WITH partner_utm AS
(
    SELECT
        partner_id,
        MAX(CASE WHEN tag_type = 'utm_campaign' THEN tag_value END) AS partner_utm_campaign,
        MAX(CASE WHEN tag_type = 'utm_source' THEN tag_value END) AS partner_utm_source,
        MAX(CASE WHEN tag_type = 'utm_medium' THEN tag_value END) AS partner_utm_medium,
        MAX(CASE WHEN tag_type = 'utm_content' THEN tag_value END) AS partner_utm_content
    FROM {{ source('int_ecosystem', 'partners_tags_campaign') }}
    GROUP BY 
        partner_id
)
SELECT 
    MP.id AS partner_id,
    MP.code AS partner_code,
    MP.name AS partner_name, 
    MC.country_code AS partner_country_code,
    MP.created_at AS partner_created_at,
    MP.email AS partner_email,
    MP.phone_number AS partner_phone_number,
    PU.partner_utm_campaign,
    PU.partner_utm_source,
    PU.partner_utm_medium,
    PU.partner_utm_content
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
LEFT JOIN partner_utm AS PU
    ON MP.id = PU.partner_id