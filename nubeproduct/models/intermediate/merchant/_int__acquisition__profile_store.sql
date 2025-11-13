WITH store_source AS (
    SELECT
        store_id,
        partner_id,
        partnership_type,
        country_code,
        device,
        created_at,
        sys_audit_updated_on
    FROM {{ ref('s__attributes__store_core__ref') }}
),
ranked_store_info_ql AS (
  SELECT 
    si.*
    , np.predicted_prob AS new_payment_probability
    , tb_cff.cutoff AS prod_cutoff
    , COALESCE(CASE WHEN np.predicted_prob >= tb_cff.cutoff  THEN 1 ELSE 0 END, 0) AS quality_lead_flag
    , ROW_NUMBER() OVER (PARTITION BY si.store_id ORDER BY si.created_at DESC) AS rownumber
  FROM store_source si
  LEFT JOIN {{ ref('marketing__models__quality_leads__ref') }} np ON si.store_id = np.store_id
  LEFT JOIN {{ source('int_data_predictors', 'marketing_cutoffs_table') }} tb_cff ON si.country_code = tb_cff.country 
                                                                                    AND np.model_id = tb_cff.model_id 
                                                                                    AND (tb_cff.device = si.device OR tb_cff.device IS NULL)
),
store_status_info AS (
    SELECT
        store_id,
        is_store_blocked,
        sys_audit_updated_on
    FROM {{ ref('s__lifecycle__store_status__ref') }}
),
tags_info AS (
    SELECT
        store_id,
        has_partner_tag,
        has_affiliate_tag,
        sys_audit_updated_on
    FROM {{ ref('merchant__attributes__store_tags__ref') }}
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
        MAX(CASE WHEN partner_id IS NOT NULL THEN campaign ELSE NULL END) AS mkt_campaign_partner_click,
        MAX(CASE WHEN trials_first_click = 1 THEN landing_page_domain ELSE NULL END) AS mkt_landing_page_domain_first_click,
        MAX(CASE WHEN trials_last_click = 1 THEN landing_page_domain ELSE NULL END) AS mkt_landing_page_domain_last_click,
        MAX(CASE WHEN trials_first_click = 1 THEN landing_page_path ELSE NULL END) AS mkt_landing_page_path_first_click,
        MAX(CASE WHEN trials_last_click = 1 THEN landing_page_path ELSE NULL END) AS mkt_landing_page_path_last_click,
        MAX(sys_audit_updated_on) AS sys_audit_updated_on
    FROM {{ ref('marketing_attribution_model') }}
    GROUP BY 1
),
partner_info AS (
    SELECT
        partner_id,
        partner_code,
        partner_exception_team,
        mkt_exclusion,
        affiliate_classification,
        fraude,
        sys_audit_updated_on
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

    ss.quality_lead_flag,

    COALESCE(att.mkt_source_last_click, 'not attributed yet') AS mkt_source_last_click,
    COALESCE(att.mkt_subteam_last_click, 'not attributed yet') AS mkt_subteam_last_click,
    att.mkt_campaign_last_click,
    COALESCE(att.mkt_source_first_click, 'not attributed yet') AS mkt_source_first_click,
    COALESCE(att.mkt_subteam_first_click, 'not attributed yet') AS mkt_subteam_first_click,
    att.mkt_campaign_first_click,

    pi.affiliate_classification AS mkt_subteam_partner_click,
    att.mkt_campaign_partner_click,
    att.mkt_landing_page_domain_first_click,
    att.mkt_landing_page_domain_last_click,
    att.mkt_landing_page_path_first_click,
    att.mkt_landing_page_path_last_click,

    CASE 
        WHEN ss.partner_id IS NOT NULL AND pi.partner_code = pi.mkt_exclusion THEN CONCAT('Affiliates - ', pi.partner_exception_team)
        WHEN ss.partner_id IS NOT NULL AND ss.partnership_type = 'affiliate' THEN 'Affiliates'
        WHEN ss.partner_id IS NOT NULL AND ss.partnership_type = 'store_development' THEN 'Partners'
        ELSE 'No affiliate'
    END AS affiliate_owner,

    COALESCE(ql_p.profile, 'not informed') AS ql_profile,
    
    CASE WHEN ssi.is_store_blocked = TRUE OR pi.fraude = 1 THEN TRUE ELSE FALSE END AS blocked_fraud_tag,

    greatest(ss.sys_audit_updated_on, ti.sys_audit_updated_on, att.sys_audit_updated_on, pi.sys_audit_updated_on, ssi.sys_audit_updated_on) AS change_timestamp
FROM ranked_store_info_ql ss
LEFT JOIN tags_info ti ON ss.store_id = ti.store_id
LEFT JOIN attribution_info att ON ss.store_id = att.store_id
LEFT JOIN partner_info pi ON ss.partner_id = pi.partner_id
LEFT JOIN ql_profile ql_p ON ss.store_id = ql_p.store_id
LEFT JOIN store_status_info ssi ON ss.store_id = ssi.store_id
WHERE ss.rownumber = 1