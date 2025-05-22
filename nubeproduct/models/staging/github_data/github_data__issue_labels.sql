{{
    config(
        materialized='incremental',
        unique_key=['repo_name', 'issue_number'],
        on_schema_change='fail',
        tags=["product","daily-4am"]
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
    labels_quick_fix
FROM
    (
        SELECT
            repo_name,
            issue_number,
            concat_ws('; ', sort_array(collect_list(name))) AS labels,
            concat_ws('; ', collect_list(CASE WHEN name IN ('AR', 'BR', 'MX', 'CO', 'CL') THEN name END)) AS labels_country,
            concat_ws('; ', collect_list(CASE WHEN name IN ('Shipping App', 'Payments App', 'Marketing App', 'Management App', 'Channels App', 'Others App') THEN name END)) AS labels_ecosystem,
            concat_ws('; ', collect_list(CASE WHEN name LIKE '%Nube -%' THEN name END)) AS labels_core,
            concat_ws('; ', collect_list(CASE WHEN name IN ('1 - WIP - Identificando problema', '2 - WIP - Entendiendo solución', '3 - WIP - Ejecutando solución', '4 - WIP - Monitoreando solución') THEN name END)) AS labels_wip,
            concat_ws('; ', collect_list(CASE WHEN name IN ('No Quick Fix', 'Quick Fix', 'Quickfix') THEN name END)) AS labels_quick_fix
        FROM
            {{ source('stg_github_data', 'issue_label') }} l  
        GROUP BY
            repo_name,
            issue_number
    ) a
