{{ config(
    materialized='table',
    on_schema_change='fail',
    unique_key=['deal_id'],
    tags=['midmarket','daily-8am']
) }}

WITH base AS (
SELECT
        d.country,
        d.deal_id,
        d.company_name,
        d.dealname,
        d.vertical,
        d.deal_owner,
        d.pipeline,
        d.stage,
        d.e_commerce,
        d.pipeline_creation_date,
        d.closedate,
        d.gmv_potencial,
        d.acquisition_channel,
        d.segmento_nuvemshop,
        d.produto_nuvemshop,
        d.date_entered_won,
        -- adicionando as colunas Problem Discovery SalesDev também na base
        d.date_entered_problem_discovery as date_entered_problem_discovery_sales_dev,
        d.store_id,
        d.associated_deal_ids
    FROM {{ ref('s__sales__pipeline__snapshot') }} d
    LEFT JOIN {{ ref('midmarket_hubspot_deleted_deals') }} del
        ON d.deal_id = cast(del.deal_id AS BIGINT)
    WHERE del.deal_id IS NULL
      AND (
            (
                UPPER(d.deal_tags) LIKE 'ASPIRATIONAL BRAND%'
                OR UPPER(d.acquisition_channel) = 'ASPIRATIONAL BRANDS'
                OR UPPER(d.hubspot_team_id) LIKE '%ASPIRA%'
                OR d.deal_owner IN ('Alejandro Vazquez', 'Regina Toledo')
            )
            AND UPPER(d.pipeline) LIKE 'SALES |%'
          )
        OR UPPER(d.pipeline) LIKE '%ASPIRA%'
),
sales_dev_link AS (
    SELECT DISTINCT
        b_exp.deal_id AS root_deal_id,
        sd.deal_id AS dealid_sales_dev,
        sd.pipeline_creation_date AS sales_dev_createdate,
        sd.pipeline,
        sd.stage AS dealstage_sales_dev,
        sd.segmento_nuvemshop,
        sd.produto_nuvemshop,
        sd.date_entered_problem_discovery_sales_dev,
        sd.date_entered_prospect_mkt
    FROM (
        SELECT b.*, id_str
        FROM base b
        LATERAL VIEW OUTER explode(
            CASE
                WHEN b.associated_deal_ids IS NULL OR trim(b.associated_deal_ids) = '' THEN array()
                ELSE split(b.associated_deal_ids, ';')
            END
        ) exploded AS id_str
    ) b_exp
    LEFT JOIN {{ ref('s__sales__dev__pipeline__snapshot') }} sd
        ON sd.deal_id = try_cast(trim(b_exp.id_str) AS BIGINT)
    WHERE trim(b_exp.id_str) <> ''
),
sales_dev_agg AS (
    SELECT
        b.deal_id AS root_deal_id,
        MAX(sdlink.dealid_sales_dev) AS dealid_sales_dev,
        MAX(sdlink.dealstage_sales_dev) AS dealstage_sales_dev,
        MAX(sdlink.sales_dev_createdate) AS date_entered_sales_dev,
        MAX(coalesce(b.date_entered_problem_discovery_sales_dev, sdlink.date_entered_problem_discovery_sales_dev)) AS date_entered_problem_discovery_sales_dev,
        MAX(sdlink.date_entered_prospect_mkt) AS date_entered_prospect_mkt,
        MAX(sdlink.segmento_nuvemshop) AS segmento_nuvemshop,
        MAX(sdlink.produto_nuvemshop) AS produto_nuvemshop
    FROM base b
    LEFT JOIN sales_dev_link sdlink ON b.deal_id = sdlink.root_deal_id
    GROUP BY b.deal_id
),
onboarding_l1 AS (
    SELECT DISTINCT
        b_exp.deal_id AS root_deal_id,
        onb.deal_id AS dealid_onboarding,
        onb.stage AS dealstage_onboarding,
        onb.store_id AS store_id_onboarding,
        onb.segmento_nuvemshop AS segmento_onboarding,
        onb.produto_nuvemshop AS produto_onboarding,
        onb.associated_deal_ids AS onboarding_associated_ids,
        onb.pipeline_creation_date AS onb_createdate,
        onb.churn_date AS onb_churn_date,
        onb.warning_date AS onb_warning_date
    FROM (
        SELECT b.*, id_str
        FROM base b
        LATERAL VIEW OUTER explode(
            CASE
                WHEN b.associated_deal_ids IS NULL OR trim(b.associated_deal_ids) = '' THEN array()
                ELSE split(b.associated_deal_ids, ';')
            END
        ) exploded AS id_str
    ) b_exp
    LEFT JOIN {{ ref('s__onboarding__pipeline__snapshot') }} onb
        ON onb.deal_id = try_cast(trim(b_exp.id_str) AS BIGINT)
    WHERE trim(b_exp.id_str) <> ''
),
onboarding_agg AS (
    SELECT
        root_deal_id,
        MAX(dealid_onboarding) AS dealid_onboarding,
        MAX(dealstage_onboarding) AS dealstage_onboarding,
        MAX(store_id_onboarding) AS store_id_onboarding,
        MAX(segmento_onboarding) AS segmento_onboarding,
        MAX(produto_onboarding) AS produto_onboarding,
        MIN(onb_createdate) AS date_entered_onboarding,
        MAX(onb_churn_date) AS date_entered_churn_onboarding,
        MAX(onb_warning_date) AS date_entered_warning_onboarding,
        MAX(onboarding_associated_ids) AS onboarding_associated_ids
    FROM onboarding_l1
    GROUP BY root_deal_id
),
success_l1 AS (
    SELECT DISTINCT
        o_exp.root_deal_id,
        s.deal_id AS dealid_success,
        s.stage AS dealstage_success,
        s.store_id AS store_id_success,
        s.produto_nuvemshop AS produto_success,
        s.pipeline_creation_date AS success_createdate,
        s.date_entered_effective_churn AS succ_churn_date,
        s.date_entered_warning AS succ_warning_date
    FROM (
        SELECT o.*, id_str
        FROM onboarding_agg o
        LATERAL VIEW OUTER explode(
            CASE
                WHEN o.onboarding_associated_ids IS NULL OR trim(o.onboarding_associated_ids) = '' THEN array()
                ELSE split(o.onboarding_associated_ids, ';')
            END
        ) exploded AS id_str
    ) o_exp
    LEFT JOIN {{ ref('s__success__pipeline__snapshot') }} s
        ON s.deal_id = try_cast(trim(o_exp.id_str) AS BIGINT)
    WHERE trim(o_exp.id_str) <> ''
),
success_agg AS (
    SELECT
        root_deal_id,
        MAX(dealid_success) AS dealid_success,
        MAX(dealstage_success) AS dealstage_success,
        MAX(store_id_success) AS store_id_success,
        MAX(produto_success) AS produto_success,
        MIN(success_createdate) AS success_createdate,
        MAX(succ_churn_date) AS succ_churn_date,
        MAX(succ_warning_date) AS succ_warning_date
    FROM success_l1
    GROUP BY root_deal_id
),
full_funnel AS (
    SELECT
        b.country,
        b.deal_id,
        b.company_name,
        b.dealname,
        b.vertical,
        b.deal_owner,
        b.pipeline,
        b.stage,
        b.e_commerce,
        b.pipeline_creation_date,
        b.closedate,
        b.gmv_potencial,
        b.acquisition_channel,
        coalesce(o.segmento_onboarding, b.segmento_nuvemshop) AS segmento_nuvemshop,
        coalesce(s.produto_success, o.produto_onboarding, b.produto_nuvemshop) AS produto_nuvemshop,
        b.date_entered_won,
        coalesce(nullif(s.store_id_success, 0), nullif(o.store_id_onboarding, 0), nullif(b.store_id, 0)) AS store_id,
        sd.dealid_sales_dev,
        sd.dealstage_sales_dev,
        sd.date_entered_sales_dev,
        sd.date_entered_problem_discovery_sales_dev,
        sd.date_entered_prospect_mkt,
        o.dealid_onboarding,
        o.dealstage_onboarding,
        o.date_entered_onboarding,
        o.date_entered_churn_onboarding,
        o.date_entered_warning_onboarding,
        s.dealid_success,
        s.dealstage_success,
        s.success_createdate AS date_entered_success,
        s.succ_churn_date AS date_entered_churn_success,
        s.succ_warning_date AS date_entered_warning_success,
        1 AS suspect,
        CASE WHEN UPPER(b.pipeline) LIKE 'SALES |%' THEN 1 ELSE 0 END AS opportunity,
        CASE WHEN UPPER(b.stage) LIKE '%WON%' THEN 1 ELSE 0 END AS won,
        CASE WHEN o.dealid_onboarding IS NOT NULL THEN 1 ELSE 0 END AS onboarding,
        CASE WHEN s.dealid_success IS NOT NULL THEN 1 ELSE 0 END AS success
    FROM base b
    LEFT JOIN sales_dev_agg sd ON sd.root_deal_id = b.deal_id
    LEFT JOIN onboarding_agg o ON o.root_deal_id = b.deal_id
    LEFT JOIN success_agg s ON s.root_deal_id = b.deal_id
    UNION ALL
    SELECT
        sd.country,
        sd.deal_id,
        sd.company_name,
        sd.dealname,
        sd.vertical,
        sd.deal_owner,
        sd.pipeline,
        sd.stage,
        NULL AS e_commerce,
        sd.pipeline_creation_date,
        sd.closedate,
        NULL AS gmv_potencial,
        NULL AS acquisition_channel,
        sd.segmento_nuvemshop,
        sd.produto_nuvemshop,
        NULL AS date_entered_won,
        NULL AS store_id,
        sd.deal_id AS dealid_sales_dev,
        sd.stage AS dealstage_sales_dev,
        sd.pipeline_creation_date AS date_entered_sales_dev,
        sd.date_entered_problem_discovery_sales_dev,
        sd.date_entered_prospect_mkt,
        NULL AS dealid_onboarding,
        NULL AS dealstage_onboarding,
        NULL AS date_entered_onboarding,
        NULL AS date_entered_churn_onboarding,
        NULL AS date_entered_warning_onboarding,
        NULL AS dealid_success,
        NULL AS dealstage_success,
        NULL AS date_entered_success,
        NULL AS date_entered_churn_success,
        NULL AS date_entered_warning_success,
        1 AS suspect,
        0 AS opportunity,
        0 AS won,
        0 AS onboarding,
        0 AS success
    FROM {{ ref('s__sales__dev__pipeline__snapshot') }} sd
    WHERE (
            (
                UPPER(sd.deal_tags) LIKE 'ASPIRATIONAL BRAND%'
                OR UPPER(sd.acquisition_channel) = 'ASPIRATIONAL BRANDS'
                OR UPPER(sd.hubspot_team_id) LIKE '%ASPIRA%'
                OR sd.deal_owner IN ('Tatiane Carneiro')
            )
        )
        AND sd.deal_id NOT IN (SELECT dealid_sales_dev FROM sales_dev_link)
),
store_info AS (
    SELECT
        lf.store_id,
        lf.churned_at AS store_info_churned_at,
        lf.current_plan_type AS current_plan,
        lf.state AS current_state
    FROM {{ ref('s__lifecycle__store_status__ref') }} lf
)
SELECT
    f.*,
    s.store_info_churned_at,
    s.current_plan,
    s.current_state,
    CASE
        WHEN NOT (UPPER(f.pipeline) LIKE 'SALES |%' AND UPPER(f.stage) = 'WON') THEN NULL
        WHEN UPPER(f.dealstage_onboarding) LIKE '%CHURN%' OR UPPER(f.dealstage_success) LIKE '%CHURN%' THEN 'Churn'
        WHEN UPPER(f.dealstage_onboarding) LIKE '%OUT OF PORTFOLIO%' 
            OR UPPER(f.dealstage_onboarding) LIKE '%DOWNGRADE%' 
            OR UPPER(f.dealstage_success) LIKE '%OUT OF PORTFOLIO%' THEN 'Downgrade'
        WHEN UPPER(f.dealstage_onboarding) LIKE '%PAUSED%' OR UPPER(f.dealstage_success) LIKE '%PAUSED%' THEN 'Paused'
        WHEN UPPER(f.dealstage_success) LIKE '%RECUPERADO CHURN%' OR UPPER(f.dealstage_success) LIKE '%WARNING%' THEN 'Warning Success'
        WHEN f.store_id IS NULL THEN 'NOK'
        WHEN f.date_entered_warning_onboarding IS NOT NULL THEN 'Warning Onboarding'
        WHEN (
            (f.dealid_onboarding IS NOT NULL OR f.dealid_success IS NOT NULL)
            AND (UPPER(f.dealstage_onboarding) IN ('GO LIVE', 'TRANSITION TO CUSTOMER SUCCESS') OR f.dealid_success IS NOT NULL)
            AND COALESCE(s.current_plan, '') <> 'enterprise'
        ) THEN 'Downgrade'
        WHEN (
            (f.date_entered_churn_onboarding IS NOT NULL OR f.date_entered_churn_success IS NOT NULL)
            OR (TO_DATE(s.store_info_churned_at) >= TO_DATE(f.date_entered_won))
        ) THEN 'Churn'
        WHEN s.current_plan = 'enterprise'
             AND (
                 f.dealid_onboarding IS NULL AND f.dealid_success IS NULL AND F.store_id IS NOT NULL
                 AND s.store_info_churned_at IS NULL
             )
        THEN 'OK'
        WHEN s.current_plan = 'enterprise'
             AND (
                 f.dealid_success IS NULL
                 OR UPPER(f.dealstage_onboarding) NOT IN ('GO LIVE', 'TRANSITION TO CUSTOMER SUCCESS')
             )
        THEN 'Pre-Onboarding'
        ELSE 'OK'
    END AS status_hubspot,
    CAST(regexp_replace(regexp_replace(dl.companies, '\\[|\\]|"', ''), '\\s', '') AS BIGINT) AS company_id,
    cp.lifecyclestage,
    cp.hs_is_target_account,
    er.direct_exchange_rate
FROM full_funnel f
LEFT JOIN store_info s ON f.store_id = s.store_id
LEFT JOIN {{ ref('hubspot__deals') }} dl ON f.deal_id = dl.deal_id
LEFT JOIN {{ ref('hubspot__companies') }} cp
  ON CAST(regexp_replace(regexp_replace(dl.companies, '\\[|\\]|"', ''), '\\s', '') AS BIGINT) = cp.company_id
LEFT JOIN {{ ref('finance_exchange_rate') }} AS er
  ON TO_DATE(f.date_entered_won) = TO_DATE(er.processed_at)
  AND f.country = er.country_currency_code