WITH partners_classification AS
(
    SELECT DISTINCT 
        MAX(MAA.id) AS id,
        MAA.affiliate_code AS partner_code,
        MIN(MAA.affiliate_classification) AS affiliate_classification,
        MIN(MAA.affiliate_tier) AS affiliate_tier,
        MIN(MAA.affiliate_main_platform) AS affiliate_main_platform,
        MAX(MAA.sys_audit_updated_on) AS sys_audit_updated_on
    FROM {{ ref('marketing_inputs_attribution') }} AS MAA
    WHERE MAA.state = 'open'
      AND MAA.input_type = 'AFFILIATE_LIST'
    GROUP BY 2
),

partner_utm AS
(
    SELECT
        partner_id,
        MAX(sys_audit_updated_on) AS sys_audit_updated_on,
        MAX(CASE WHEN tag_type = 'utm_campaign' THEN tag_value END) AS partner_utm_campaign,
        MAX(CASE WHEN tag_type = 'utm_source' THEN tag_value END) AS partner_utm_source,
        MAX(CASE WHEN tag_type = 'utm_medium' THEN tag_value END) AS partner_utm_medium,
        MAX(CASE WHEN tag_type = 'utm_content' THEN tag_value END) AS partner_utm_content
    FROM {{ source('int_ecosystem', 'partners_tags_campaign') }}
    WHERE tag_type IN ('utm_campaign', 'utm_source', 'utm_medium', 'utm_content')
    GROUP BY partner_id
),

partner_exception AS
(
    SELECT
        MAX(id) AS id,
        partner_code AS mkt_exclusion,
        team,
        subteam,
        MAX(sys_audit_updated_on) AS sys_audit_updated_on
    FROM {{ ref('marketing_inputs_attribution__partner_exception') }}
    GROUP BY 2, 3, 4
),

partner_fraud AS 
(
    SELECT
        MAX(id) AS id,  
        partner_code,
        fraude,
        MAX(sys_audit_updated_on) AS sys_audit_updated_on
    FROM {{ ref('marketing_inputs_attribution__partner_fraud') }}
    GROUP BY 2, 3
)

SELECT 
    MP.partner_id,
    MP.partner_code,
    MP.partner_name, 
    MC.country_code AS partner_country_code,
    MP.partner_created_at,
    MP.partner_email,
    MP.partner_phone_number,

    -- UTM info
    PU.partner_utm_campaign,
    PU.partner_utm_source,
    PU.partner_utm_medium,
    PU.partner_utm_content,

    -- Exceptions and Flags
    PE.mkt_exclusion,
    CASE WHEN PE.mkt_exclusion IS NOT NULL THEN 1 ELSE 0 END AS flag_partner_exception,

    -- Timestamp unificado
    greatest(
        PU.sys_audit_updated_on, 
        PE.sys_audit_updated_on, 
        PF.sys_audit_updated_on, 
        PS.sys_audit_updated_on
    ) AS change_timestamp,

    -- Fonte dos inputs
    TRIM(TRAILING ',' FROM
        CASE WHEN PF.id IS NOT NULL THEN 'partner_fraud,' ELSE '' END ||
        CASE WHEN PS.id IS NOT NULL THEN 'affiliate_classification,' ELSE '' END ||
        CASE WHEN PE.id IS NOT NULL THEN 'partner_exception,' ELSE '' END
    ) AS input_sources_partners,

    -- Outras colunas
    PE.team AS partner_team,
    PE.subteam AS partner_subteam,
    PF.fraude,
    PS.affiliate_tier,
    PS.affiliate_main_platform,

    CASE
        WHEN MP.partner_code IS NOT NULL AND PE.mkt_exclusion IS NOT NULL THEN 'Other Mkt Teams'
        WHEN MP.partner_code IS NOT NULL AND PE.mkt_exclusion IS NULL THEN COALESCE(PS.affiliate_classification, 'Long Tail')
        ELSE 'Long Tail'
    END AS affiliate_classification

FROM {{ ref('s__partnerships__general__partners__event') }} AS MP
LEFT JOIN (
    SELECT DISTINCT
        country_id,
        country_code
    FROM {{ ref('dim_location_country') }}
) AS MC
    ON MP.partner_country_id = MC.country_id

LEFT JOIN partner_utm AS PU
    ON MP.partner_id = PU.partner_id

LEFT JOIN partner_exception AS PE
    ON PE.mkt_exclusion = MP.partner_code

LEFT JOIN partner_fraud AS PF 
    ON PF.partner_code = MP.partner_code 

LEFT JOIN partners_classification AS PS
    ON PS.partner_code = MP.partner_code
