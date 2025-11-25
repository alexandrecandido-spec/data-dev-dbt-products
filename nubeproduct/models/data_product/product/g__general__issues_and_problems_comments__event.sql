{{
    config(
        materialized='table',
        unique_key=['issue_number', 'repo_name', 'comment_id'],
        partition_by='comment_date_month',
        tags=['intermediate', 'github']
    )
}}

-- CTE 1: Datos Base (Issues, Comentarios y Tiendas)
WITH base_data AS (
    SELECT
        pips.repo_name,
        pips.issue_number,
        pips.title,
        pips.created_at,
        pips.closed_at,
        pips.labels,
        pips.labels_tipo,
        pips.labels_domain,
        pips.labels_country,
        pips.impact,
        pips.status_last_wbr, -- De la tabla pips
        pips.onboarding_ar,
        pips.onboarding_br,
        
        -- Datos del Comentario y Tienda
        ic.id AS comment_id,
        ic.author AS comment_author,
        ic.is_relevant AS comment_is_relevant,
        p.store_id,
        cast(ic.github_created_at AS date) AS comment_date,
        
        -- Calculamos el mes de la fecha del comentario para partición
        {{ dbt_utils.date_trunc('month', 'cast(ic.github_created_at as date)') }} AS comment_date_month,
        
        -- Dimensiones de la Tienda
        cmm.country_code AS store_country_code,
        cmm.current_segment_name AS store_segment_name,
        msi.domain AS store_name
        
    FROM {{ ref('product_issues_and_problems_summary') }} pips  -- Cambiado a ref
    -- Usar el JOIN de la tercera query para comentarios y tiendas
    INNER JOIN {{ source('github_data', 'issue_comment') }} ic 
        ON pips.repo_name = ic.repo_name AND pips.issue_number = ic.issue_number
    LEFT JOIN {{ source('github_data', 'issue_store') }} p 
        ON ic.repo_name = p.repo_name AND ic.issue_number = p.issue_number AND ic.id = p.comment_id
    LEFT JOIN {{ ref('company_metrics_merchant_info') }} cmm 
        ON p.store_id = cmm.store_id
    LEFT JOIN {{ source('curated_moltres', 'mwp_store_info') }} msi 
        ON p.store_id = msi.id

    -- Filtro Incremental: Basado en el timestamp del comentario creado
    {% if is_incremental() %}
    WHERE ic.github_created_at >= (
        SELECT COALESCE(MAX(comment_date), DATE '2023-01-01') FROM {{ this }}
    )
    {% else %}
    WHERE ic.github_created_at >= DATE '2024-01-01' -- Ajustar fecha inicial si es necesario
    {% endif %}