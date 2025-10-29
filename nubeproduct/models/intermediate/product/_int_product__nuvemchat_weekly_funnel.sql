WITH run_period AS (
    SELECT 
        current_date - INTERVAL '7 days' AS period_start_date,
        current_date AS period_end_date
),

active_base AS (
    SELECT
        gp.grupo as plan_group,
        msi.state,
        msi.current_segment,
        msi.country,
        rp.period_start_date AS date_from,
        COUNT(CASE 
            WHEN msi.created_at IS NOT NULL 
                AND DATE(msi.created_at) >= rp.period_start_date 
                AND DATE(msi.created_at) < rp.period_end_date
            THEN 1 END) AS period_enabled_count,
        count(distinct msi.store_id) as enabled_stores_count
    FROM {{ ref('moltres__mwp_store_info') }} msi 
    LEFT JOIN {{ ref('operations_grouping_plans') }} gp on gp.plan = msi.plan
    CROSS JOIN run_period rp
    WHERE msi.state NOT IN (3,4)
    GROUP BY 1,2,3,4,5
)


    SELECT 
        s.plan_group,
        s.state,
        s.current_segment,
        s.country,
        rp.period_start_date AS date_from,
        COALESCE(ab.enabled_stores_count, 0) as enabled_stores_count,
        -- Period metrics: what happened since the last run
        COUNT(CASE 
            WHEN s.installed_at IS NOT NULL 
                AND DATE(s.installed_at) >= rp.period_start_date 
                AND DATE(s.installed_at) < rp.period_end_date
            THEN 1 END) AS period_installed_count,
        COUNT(CASE 
            WHEN s.trial_start_date IS NOT NULL 
                AND DATE(s.trial_start_date) >= rp.period_start_date 
                AND DATE(s.trial_start_date) < rp.period_end_date
            THEN 1 END) AS period_started_trial_count,
        COUNT(CASE 
            WHEN s.last_paid_date IS NOT NULL 
                AND DATE(s.last_paid_date) >= rp.period_start_date 
                AND DATE(s.last_paid_date) < rp.period_end_date
            THEN 1 END) AS period_has_paid_count,
        COUNT(CASE 
            WHEN s.chatnube_state_group = 'churn' 
                AND s.churned_date IS NOT NULL
                AND DATE(s.churned_date) >= rp.period_start_date 
                AND DATE(s.churned_date) < rp.period_end_date
            THEN 1 END) AS period_churned_count,
        -- Cumulative metrics: all-time totals
        COUNT(CASE 
            WHEN s.installed_at IS NOT NULL 
            THEN 1 END) AS cumulative_installed_count,
        COUNT(CASE 
            WHEN s.trial_start_date IS NOT NULL  
            THEN 1 END) AS cumulative_started_trial_count,
        COUNT(CASE 
            WHEN s.last_paid_date IS NOT NULL 
            THEN 1 END) AS cumulative_has_paid_count, 
        COUNT(CASE 
            WHEN s.chatnube_state_group = 'churn' 
                AND s.churned_date IS NOT NULL
            THEN 1 END) AS cumulative_churned_count,
        COUNT(*) AS total_stores_count
    FROM  {{ ref('product_nuvemchat_stores') }} s
    CROSS JOIN run_period rp
    LEFT JOIN active_base ab on ab.state = s.state and ab.current_segment = s.current_segment and ab.plan_group = s.plan_group and ab.country = s.country and ab.date_from = rp.period_start_date
    WHERE s.store_id IS NOT NULL
    GROUP BY 
        s.plan_group,
        s.state,
        s.current_segment,
        s.country,
        rp.period_start_date,
        ab.enabled_stores_count

