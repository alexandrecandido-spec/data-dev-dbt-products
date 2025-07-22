{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['repo_name','store_id','issue_number'],
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}

WITH source_data AS (
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
        db.comment_date as comment_date,
        current_timestamp() AS _current_timestamp_for_audit, -- Usaremos esto para el nuevo timestamp
        'data-dev-dbt-products' AS sys_audit_created_by,
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

    {% if is_incremental() %}
    WHERE
        l.sys_audit_updated_on >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR v.sys_audit_updated_on >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR i.sys_audit_updated_at >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR s.sys_audit_updated_on >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR onb.sys_audit_updated_on >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR w1.sys_audit_updated_on >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR w2.sys_audit_updated_on >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR w3.sys_audit_updated_on >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR w4.sys_audit_updated_on >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR mi.sys_audit_updated_at >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR db.sys_audit_updated_at >= (SELECT coalesce(MAX(a.sys_audit_updated_on),'1900-01-01') FROM {{ this }} a )
        OR v.store_id IN (
            SELECT target_table.store_id
            FROM {{ this }} AS target_table
            LEFT JOIN {{ ref('_int_midmarket_success_stores_issues_and_problems') }} AS mm_s_new
                ON target_table.store_id = mm_s_new.store_id
            WHERE mm_s_new.in_portfolio IS DISTINCT FROM target_table.status_last_wbr
        )
    {% endif %}
),

final_selection AS (
    SELECT
        sd.*, -- Select all columns from source_data
        -- Now, apply the audit column logic. target_table is available here via the LEFT JOIN
        {% if is_incremental() %}
        COALESCE(target_table.sys_audit_created_on, sd._current_timestamp_for_audit) AS sys_audit_created_on,
        {% else %}
        sd._current_timestamp_for_audit AS sys_audit_created_on,
        {% endif %}

        {% if is_incremental() %}
        CASE
            WHEN target_table.repo_name IS NOT NULL AND(
                    sd.created_at IS DISTINCT FROM target_table.created_at OR
                    sd.closed_at IS DISTINCT FROM target_table.closed_at OR
                    sd.state IS DISTINCT FROM target_table.state OR
                    sd.comments IS DISTINCT FROM target_table.comments OR
                    sd.author IS DISTINCT FROM target_table.author OR
                    sd.html_url IS DISTINCT FROM target_table.html_url OR
                    sd.title IS DISTINCT FROM target_table.title OR
                    sd.churned_at IS DISTINCT FROM target_table.churned_at OR
                    sd.current_segment IS DISTINCT FROM target_table.current_segment OR
                    sd.country IS DISTINCT FROM target_table.country OR
                    sd.plan IS DISTINCT FROM target_table.plan OR
                    sd.store_created_at IS DISTINCT FROM target_table.store_created_at OR
                    sd.labels_tipo IS DISTINCT FROM target_table.labels_tipo OR
                    sd.labels_domain IS DISTINCT FROM target_table.labels_domain OR
                    sd.labels_country IS DISTINCT FROM target_table.labels_country OR
                    sd.labels IS DISTINCT FROM target_table.labels OR
                    sd.labels_wip IS DISTINCT FROM target_table.labels_wip OR
                    sd.labels_quick_fix IS DISTINCT FROM target_table.labels_quick_fix OR
                    sd.wip_1_last_updated IS DISTINCT FROM target_table.wip_1_last_updated OR
                    sd.wip_1_last_deleted IS DISTINCT FROM target_table.wip_1_last_deleted OR
                    sd.wip_2_last_updated IS DISTINCT FROM target_table.wip_2_last_updated OR
                    sd.wip_2_last_deleted IS DISTINCT FROM target_table.wip_2_last_deleted OR
                    sd.wip_3_last_updated IS DISTINCT FROM target_table.wip_3_last_updated OR -- Corrected alias here
                    sd.wip_3_last_deleted IS DISTINCT FROM target_table.wip_3_last_deleted OR -- Corrected alias here
                    sd.wip_4_last_updated IS DISTINCT FROM target_table.wip_4_last_updated OR -- Corrected alias here
                    sd.wip_4_last_deleted IS DISTINCT FROM target_table.wip_4_last_deleted OR -- Corrected alias here
                    sd.milestone_title IS DISTINCT FROM target_table.milestone_title OR
                    sd.milestone_created_at IS DISTINCT FROM target_table.milestone_created_at OR
                    sd.onboarding_ar IS DISTINCT FROM target_table.onboarding_ar OR
                    sd.onboarding_br IS DISTINCT FROM target_table.onboarding_br OR
                    sd.impact IS DISTINCT FROM target_table.impact OR
                    sd.comment_date IS DISTINCT FROM target_table.comment_date OR
                    sd.status_last_wbr IS DISTINCT FROM target_table.status_last_wbr) -- Included for update trigger
                    THEN sd._current_timestamp_for_audit
                ELSE target_table.sys_audit_updated_on
        END AS sys_audit_updated_on
        {% else %}
        sd._current_timestamp_for_audit AS sys_audit_updated_on
        {% endif %}
        
    FROM source_data sd
    {% if is_incremental() %}
    LEFT JOIN {{ this }} AS target_table
        ON sd.repo_name = target_table.repo_name
        AND sd.store_id = target_table.store_id
        AND sd.issue_number = target_table.issue_number
    {% endif %}
)

SELECT
    repo_name,
    issue_number,
    created_at,
    closed_at,
    state,
    comments,
    author,
    html_url,
    title,
    store_id,
    churned_at,
    current_segment,
    country,
    plan,
    store_created_at,
    labels_tipo,
    labels_domain,
    labels_country,
    labels,
    labels_wip,
    labels_quick_fix,
    wip_1_last_updated,
    wip_1_last_deleted,
    wip_2_last_updated,
    wip_2_last_deleted,
    wip_3_last_updated,
    wip_3_last_deleted,
    wip_4_last_updated,
    wip_4_last_deleted,
    milestone_title,
    milestone_created_at,
    status_last_wbr,
    onboarding_ar,
    onboarding_br,
    impact,
    comment_date,
    sys_audit_created_on,
    sys_audit_created_by,
    sys_audit_updated_on,
    sys_audit_updated_by
FROM final_selection