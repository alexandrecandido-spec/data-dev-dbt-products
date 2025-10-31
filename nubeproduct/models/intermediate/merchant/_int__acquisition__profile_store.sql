WITH store_source AS (
    SELECT
        store_id,
        partner_id,
        partnership_type
    FROM {{ ref('merchant__attributes__store_info__ref') }}
), 
tags_info AS (
    SELECT
        store_id,
        has_partner_tag,
        has_affiliate_tag
    FROM {{ ref('merchant__attributes__store_tags__ref') }}
),
ql_flag AS (
    SELECT
        store_id,
        CASE WHEN new_payment_probability >= prod_cutoff THEN 1 ELSE 0 END AS quality_lead_flag
    FROM {{ ref('_int_marketing_store_info__get_quality_leads_info') }}
),
attribution_info AS (
    SELECT 
        store_id,
        MAX(CASE WHEN trials_last_click = 1 THEN mkt_source ELSE NULL END) AS mkt_source_last_click,
        MAX(CASE WHEN trials_last_click = 1 THEN mkt_subteam ELSE NULL END) AS mkt_subteam_last_click,
        MAX(CASE WHEN trials_last_click = 1 THEN campaign ELSE NULL END) AS mkt_campaign_last_click,
        MAX(CASE WHEN trials_first_click = 1 THEN mkt_source ELSE NULL END) AS mkt_source_first_click,
        MAX(CASE WHEN trials_first_click = 1 THEN mkt_subteam ELSE NULL END) AS mkt_subteam_first_click,
        MAX(CASE WHEN trials_first_click = 1 THEN campaign ELSE NULL END) AS mkt_campaign_first_click,
        MAX(CASE WHEN partner_id IS NOT NULL THEN mkt_source ELSE NULL END) AS mkt_source_partner_click,
        MAX(CASE WHEN partner_id IS NOT NULL THEN mkt_subteam ELSE NULL END) AS mkt_subteam_partner_click,
        MAX(CASE WHEN partner_id IS NOT NULL THEN campaign ELSE NULL END) AS mkt_campaign_partner_click,
        MAX(CASE WHEN trials_first_click = 1 THEN landing_page_domain ELSE NULL END) AS mkt_landing_page_domain_first_click,
        MAX(CASE WHEN trials_last_click = 1 THEN landing_page_domain ELSE NULL END) AS mkt_landing_page_domain_last_click,
        MAX(CASE WHEN trials_first_click = 1 THEN landing_page_path ELSE NULL END) AS mkt_landing_page_path_first_click,
        MAX(CASE WHEN trials_last_click = 1 THEN landing_page_path ELSE NULL END) AS mkt_landing_page_path_last_click
    FROM {{ ref('marketing_attribution_model') }}
    GROUP BY 1
),
partner_info AS (
    SELECT
        partner_id,
        partner_code,
        partner_team,
        mkt_exclusion
    FROM {{ ref('s__general__partners_info__ref') }}
),
ql_profile AS (
    SELECT
        store_id,
        profile
    FROM {{ ref('_int__last_ql_profile') }}
)
SELECT
    ss.store_id,
    ss.partner_id,

    CASE 
        WHEN ss.partnership_type = 'affiliate' THEN 'Affiliate' 
        WHEN ti.has_partner_tag = 1 AND ti.has_affiliate_tag = 0 THEN 'Partner' 
        ELSE 'Nuvemshop' 
    END AS tag_acquired_by,

    ql.quality_lead_flag,

    att.mkt_source_last_click,
    att.mkt_subteam_last_click,
    att.mkt_campaign_last_click,
    att.mkt_source_first_click,
    att.mkt_subteam_first_click,
    att.mkt_campaign_first_click,
    att.mkt_source_partner_click,
    att.mkt_subteam_partner_click,
    att.mkt_campaign_partner_click,
    att.mkt_landing_page_domain_first_click,
    att.mkt_landing_page_domain_last_click,
    att.mkt_landing_page_path_first_click,
    att.mkt_landing_page_path_last_click,

    CASE 
        WHEN ss.partner_id IS NOT NULL AND pi.partner_code = pi.mkt_exclusion THEN CONCAT('Affiliates - ' ,pi.partner_team)					
        WHEN ss.partner_id IS NOT NULL AND ss.partnership_type = 'affiliate' THEN 'Affiliates'				
        WHEN ss.partner_id IS NOT NULL AND ss.partnership_type = 'store_development' THEN 'Partners' 
        ELSE 'No' 
    END AS flag_affiliate,

    ql_p.profile AS ql_profile
FROM store_source ss
LEFT JOIN tags_info ti ON ss.store_id = ti.store_id
LEFT JOIN ql_flag ql ON ss.store_id = ql.store_id
LEFT JOIN attribution_info att ON ss.store_id = att.store_id
LEFT JOIN partner_info pi ON ss.partner_id = pi.partner_id
LEFT JOIN ql_profile ql_p ON ss.store_id = ql_p.store_id