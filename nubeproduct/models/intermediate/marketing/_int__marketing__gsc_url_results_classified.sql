WITH base AS (
    SELECT * FROM {{ ref('_int__marketing__gsc_url_results_prep') }}
),

/* 1. ENRIQUECIMIENTO CON INPUTS */
url_enriched AS (
    SELECT
        b.*,
        u.team AS url_team,
        u.subteam AS url_subteam,
        u.sys_audit_updated_on AS url_sys_audit_updated_on,
        CASE 
            WHEN u.team = 'Growth' THEN 'Content Hub' 
            ELSE u.team 
        END AS input_based_group
    FROM base b
    LEFT JOIN LATERAL (
        SELECT team, subteam, sys_audit_updated_on
        FROM {{ ref('s__general__mkt_attribution_github_inputs_url__ref') }} u
        WHERE u.landing_page_domain = b.domain_clean
          AND POSITION(u.landing_page_path IN b.path_clean) > 0
        ORDER BY LENGTH(u.landing_page_path) DESC
        LIMIT 1
    ) u ON TRUE
),

/* 2. CÁLCULO DE PAGE GROUP (Usando Macro) */
calc_group AS (
    SELECT
        e.*,
        {{ marketing_classify_page_group(
            'e.input_based_group', 
            'e.path_clean', 
            'e.domain_clean'
        ) }} AS page_group
    FROM url_enriched e
),

/* 3. CÁLCULO DE PAGE SUBGROUP Y PAÍS (Usando Macros) */
calc_subgroup AS (
    SELECT
        c.*,
        -- Macro de Subgrupo (Recibe el Grupo calculado arriba + inputs)
        {{ marketing_classify_page_subgroup(
            'c.page_group', 
            'c.url_subteam', 
            'c.full_url', 
            'c.path_clean', 
            'c.domain_clean'
        ) }} AS page_subgroup,

        -- Macro de País (Recibe Fecha para aplicar lógica histórica vs nueva)
        {{ marketing_classify_country(
            'c.domain_clean', 
            'c.path_clean', 
            'c.country_name',
            'c.date'
        ) }} AS classified_country

    FROM calc_group c
),

/* 4. PREPARACIÓN INCREMENTAL (Hash & Timestamp) */
final_prep AS (
    SELECT
        c.*,
        
        -- Timestamp para detectar cambios en inputs
        GREATEST(
            CAST(c.date AS TIMESTAMP), 
            COALESCE(c.url_sys_audit_updated_on, TIMESTAMP '1900-01-01')
        ) AS change_timestamp_incremental,
        
        -- Input sources para auditoría
        CASE WHEN c.url_team IS NOT NULL THEN 'url' ELSE '' END AS input_sources,

        -- Hash único de la fila (CDC)
        {{ marketing_mpt_hash([
            'c.date', 
            'c.full_url', 
            'c.search_type', 
            'c.country_name', 
            'c.device', 
            'c.impressions', 
            'c.clicks', 
            'c.page_group', 
            'c.page_subgroup',
            'c.classified_country'
        ]) }} AS row_hash

    FROM calc_subgroup c
)

/* 5. SELECCIÓN FINAL LIMPIA */
SELECT
    year_month_day_code,
    date,
    full_url,
    path,
    search_type,
    country_name,
    device,
    impressions,
    clicks,
    average_position,
    page_group,
    page_subgroup,
    classified_country,
    change_timestamp_incremental,
    input_sources,
    row_hash
FROM final_prep