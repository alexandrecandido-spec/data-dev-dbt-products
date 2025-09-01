{{
    config(
        materialized='table',
        unique_key=['repo_name','store_id','issue_number'],
        on_schema_change='fail',
        tags=["daily-10am"]
    )
}}

    SELECT distinct
        i.repo_name,
        i.issue_number,
        i.created_at,
        i.closed_at,
        i.state,
        i.comments,
        i.author,
        i.html_url,
        i.title,
        NULLIF(regexp_extract(i.title, '^\\s*\\[([^\\]]+)\\]', 1), '') AS pain_point,
        v.store_id,
        s.churned_at,
        s.current_segment,
        s.country,
        s.plan,
        cast(s.created_at as date) as store_created_at,
        l.labels_tipo,
        l.labels_domain,
        l.labels_country,
        l.labels,
        l.labels_wip,
        labels_quick_fix,
        w1.wip_last_updated as wip_1_last_updated,
        w1.wip_last_deleted as wip_1_last_deleted,
        w2.wip_last_updated as wip_2_last_updated,
        w2.wip_last_deleted as wip_2_last_deleted,
        w3.wip_last_updated as wip_3_last_updated,
        w3.wip_last_deleted as wip_3_last_deleted,
        w4.wip_last_updated as wip_4_last_updated,
        w4.wip_last_deleted as wip_4_last_deleted,
        mi.milestone_title,
        mi.milestone_created_at,
        mm_stores.in_portfolio = true as status_last_wbr, -- Valor actual de Success
        case when onb.country = 'AR' then 1 end as onboarding_ar,
        case when onb.country = 'BR' then 1 end as onboarding_br,
        case when onb.country in ('AR','BR') or (mm_stores.in_portfolio is not null and mm_stores.in_portfolio=true) then db.impact end as impact,
        case when v.store_id is not null and db.comment_date is null then i.created_at else db.comment_date end as comment_date,
        current_timestamp() AS sys_audit_created_on,
        'data-dev-dbt-products' AS sys_audit_created_by,
        current_timestamp() as sys_audit_updated_on,
        'data-dev-dbt-products' AS sys_audit_updated_by
    FROM {{ ref('_int_github_data_issues_problems_main') }} i
    LEFT JOIN {{ ref('github_data__merchant_impact') }} v ON i.repo_name = v.repo_name AND i.issue_number = v.issue_number
    LEFT JOIN {{ ref('moltres__mwp_store_info') }} s ON s.store_id = v.store_id
    LEFT JOIN {{ ref('github_data__issue_labels') }} l ON i.repo_name = l.repo_name AND i.issue_number = l.issue_number
    LEFT JOIN {{ ref('_int_github_data_issues_problems_hubspot_onboarding') }} onb ON onb.store_id = v.store_id
    LEFT JOIN {{ ref('github_data__issue_wip_labels') }} w1 ON i.repo_name = w1.repo_name AND i.issue_number = w1.issue_number AND w1.wip_label = '1 - WIP - Identificando problema'
    LEFT JOIN {{ ref('github_data__issue_wip_labels') }} w2 ON i.repo_name = w2.repo_name AND i.issue_number = w2.issue_number AND w2.wip_label = '2 - WIP - Entendiendo solucion'
    LEFT JOIN {{ ref('github_data__issue_wip_labels') }} w3 ON i.repo_name = w3.repo_name AND i.issue_number = w3.issue_number AND w3.wip_label = '3 - WIP - Ejecutando solucion'
    LEFT JOIN {{ ref('github_data__issue_wip_labels') }} w4 ON i.repo_name = w4.repo_name AND i.issue_number = w4.issue_number AND w4.wip_label = '4 - WIP - Monitoreando solucion'
    LEFT JOIN {{ ref('_int_github_data_issues_problems_milestones') }} mi ON i.repo_name = mi.repo_name AND i.issue_number = mi.issue_number
    LEFT JOIN {{ ref('_int_github_data_issues_problems_comments') }} db ON i.repo_name = db.repo_name AND i.issue_number = db.issue_number AND v.store_id = db.store_id
    LEFT JOIN {{ ref('_int_midmarket_success_stores_issues_and_problems') }} mm_stores ON v.store_id = mm_stores.store_id
