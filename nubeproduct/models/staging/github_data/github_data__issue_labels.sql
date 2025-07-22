{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number'],
        incremental_strategy='merge',
        on_schema_change='fail',
        tags=["product","daily-8am"]
    )
}}

SELECT
    repo_name,
    issue_number,
    CASE
        WHEN labels like '%Platform Development%' THEN 'App'
        WHEN labels not like '%Nube - %' THEN 'Others'
        WHEN labels like '%Nube - %' THEN 'Core'
        ELSE ''
    END AS labels_tipo,
    CASE
        WHEN labels like '%Platform Development%' THEN labels_ecosystem
        WHEN labels like '%Nube -%' THEN labels_core
    END AS labels_domain,
    labels_country,
    labels,
    labels_wip,
    labels_quick_fix,
    CAST(to_date(github_created_at, 'yyyyMMdd') AS STRING) AS year_month_day_code,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    (
        SELECT
            repo_name,
            issue_number,
            min(github_created_at) as github_created_at,
            concat_ws('; ', sort_array(collect_list(name))) AS labels,
            concat_ws('; ', collect_list(CASE WHEN name IN ('AR', 'BR', 'MX', 'CO', 'CL') THEN name END)) AS labels_country,
            concat_ws('; ', collect_list(CASE WHEN name IN ('Shipping App', 'Payments App', 'Marketing App', 'Management App', 'Channels App', 'Others App') THEN name END)) AS labels_ecosystem,
            concat_ws('; ', collect_list(CASE WHEN name LIKE '%Nube -%' THEN name END)) AS labels_core,
            concat_ws('; ', collect_list(CASE WHEN name IN ('1 - WIP - Identificando problema', '2 - WIP - Entendiendo solucion', '3 - WIP - Ejecutando solucion', '4 - WIP - Monitoreando solucion') THEN name END)) AS labels_wip,
            concat_ws('; ', collect_list(CASE WHEN name IN ('No Quick Fix', 'Quick Fix', 'Quickfix') THEN name END)) AS labels_quick_fix,
            max(sys_audit_updated_at) as sys_audit_updated_at
        FROM
            {{ source('stg_github_data', 'issue_label') }} l  
        GROUP BY
            repo_name,
            issue_number
    ) a
    
    {% if is_incremental() %}
    WHERE
        sys_audit_updated_at >= (select coalesce(max(j.sys_audit_updated_on),'1900-01-01') from {{ this }} j)
    {% endif %}

