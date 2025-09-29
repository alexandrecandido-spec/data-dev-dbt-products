WITH base AS (
    SELECT
        agg.*,

        /* Normalizaciones a lower para machear inputs */
        LOWER(REGEXP_REPLACE(agg.landing_page_domain, '^(?:https?://)?(?:www\\.)?', '')) AS domain_clean,
        LOWER(COALESCE(agg.landing_page_path, ''))                                       AS path_clean,
        LOWER(COALESCE(agg.landing_page, ''))                                            AS landing_page_lc,
        LOWER(COALESCE(agg.env, ''))                                                     AS env_lc,

        /* Normalización GA4: (none)/(not set) a vacío */
        CASE
          WHEN LOWER(COALESCE(agg.last_source,'')) IN ('(none)','(not set)') THEN ''
          ELSE LOWER(COALESCE(agg.last_source,''))
        END AS last_source_lc,
        CASE
          WHEN LOWER(COALESCE(agg.last_medium,'')) IN ('(none)','(not set)') THEN ''
          ELSE LOWER(COALESCE(agg.last_medium,''))
        END AS last_medium_lc,
        CASE
          WHEN LOWER(COALESCE(agg.last_campaign,'')) IN ('(none)','(not set)') THEN ''
          ELSE LOWER(COALESCE(agg.last_campaign,''))
        END AS last_campaign_lc

    FROM {{ ref('marketing_ga4_sessions_aggregated') }} agg
),

/* Enriquecimiento por URL (match más largo de path) */
url_enriched AS (
    SELECT
        b.*,
        u.team    AS url_team,
        u.subteam AS url_subteam
    FROM base b
    LEFT JOIN LATERAL (
        SELECT team, subteam
        FROM {{ ref('marketing_inputs_attribution__url') }} u
        WHERE u.landing_page_domain = b.domain_clean
          AND POSITION(u.landing_page_path IN b.path_clean) > 0
        ORDER BY LENGTH(u.landing_page_path) DESC
        LIMIT 1
    ) u ON TRUE
),

/* Enriquecimiento por insti (match más largo de path) */
insti_enriched AS (
    SELECT
        u.*,
        i.team    AS insti_team,
        i.subteam AS insti_subteam
    FROM url_enriched u
    LEFT JOIN LATERAL (
        SELECT team, subteam
        FROM {{ ref('marketing_inputs_attribution__insti') }} i
        WHERE i.landing_page_domain = u.domain_clean
          AND POSITION(i.landing_page_path IN u.path_clean) > 0
        ORDER BY LENGTH(i.landing_page_path) DESC
        LIMIT 1
    ) i ON TRUE
),

/* Enriquecimiento por UTM (source/medium → source_mkt/subteam) */
utm_enriched AS (
    SELECT
        i.*,
        ut.source_mkt,
        ut.subteam AS utm_subteam
    FROM insti_enriched i
    LEFT JOIN LATERAL (
        SELECT source_mkt, subteam
        FROM {{ ref('marketing_inputs_attribution__utm') }} ut
        WHERE ut.source = i.last_source_lc
          AND ut.medium = i.last_medium_lc
        LIMIT 1
    ) ut ON TRUE
),

/* Subteam por campaña (fuente/medium coincidente) */
subcam_enriched AS (
    SELECT
        u.*,
        sc.subteam      AS subteam_cam,
        sc.utm_campaign AS utm_campaign_cam
    FROM utm_enriched u
    LEFT JOIN LATERAL (
        SELECT subteam, utm_campaign
        FROM {{ ref('marketing_inputs_attribution__subteam') }} sc
        WHERE sc.utm_source = u.last_source_lc
          AND sc.utm_medium = u.last_medium_lc
        LIMIT 1
    ) sc ON TRUE
),

/* url_content_type = fallback de subteam URL / insti */
content_type_enriched AS (
    SELECT
        s.*,
        COALESCE(s.url_subteam, s.insti_subteam) AS url_content_type
    FROM subcam_enriched s
),

/* Type of page */
page_type_enriched AS (
    SELECT
        s.*,
        CASE
            WHEN s.url_content_type IN ('Blog', 'Downloadables', 'Tools', 'Trilhas') THEN 'Content Pages'
            ELSE 'Other Pages'
        END AS type_of_page
    FROM content_type_enriched s
),

/* Insti pages */
insti_pages_enriched AS (
    SELECT
        s.*,
        CASE
          WHEN (
                 /* A) env institucional */
                 s.env_lc IN ('insti','partners','next')
                 /* B) URLs exactas o paths permitidos */
                 OR (
                      s.landing_page_lc IN (
                        'https://www.nuvemshop.com.br/',
                        'https://www.nuvemshop.com.br/vender/online',
                        'https://www.tiendanube.com/',
                        'https://www.tiendanube.com/mx',
                        'https://www.tiendanube.com/mx/',
                        'https://www.tiendanube.com/cl',
                        'https://www.tiendanube.com/cl/',
                        'https://www.tiendanube.com/co',
                        'https://www.tiendanube.com/co/'
                      )
                      OR REGEXP_LIKE(
                           s.path_clean,
                           '^/(site|loja-virtual|compare|plano-gratis|planos-e-precos|planes-y-precios|compara|tienda-gratis|vender/online|crear-mi-tienda-online|login|recuperar-contrasena|nuvem-envio|nuvem-pago|nuvem-pay|solucoes|soluciones|next|ecossistema|parceiros|ecosistema|socios|asociados|loja-layouts-nuvem|tienda-disenos-nube|funcionalidades|eventos|dropshipping|especialistas-nube|evolucion|vender)(/|$)'
                         )
                    )
               )
           AND COALESCE(s.type_of_page,'') <> 'Content Pages'
           AND (
                 COALESCE(s.total_trials,0) > 0
                 OR (
                      POSITION('/admin' IN s.path_clean) = 0
                  AND POSITION('/facebook/facebook-business-extension' IN s.path_clean) = 0
                  AND POSITION('admin'  IN s.last_source_lc) = 0
                  AND POSITION('awareness' IN s.last_campaign_lc) = 0
                    )
               )
          THEN 'Insti'
          ELSE 'Other'
        END AS insti_pages
    FROM page_type_enriched s
)

SELECT
    s.*,

    /* URL owner */
    COALESCE(s.url_team, s.insti_team) AS url_owner,

    /* ===== MKT SOURCE ===== */
    CASE
        /* Partners por dominio de partners + direct-like (source ''/direct; medium/campaign ''/direct) */
        WHEN s.domain_clean IN ('partners.tiendanube.com','partners.nuvemshop.com.br')
         AND (s.last_source_lc  IN ('','direct'))
         AND (s.last_medium_lc  IN ('','direct'))
         AND (s.last_campaign_lc IN ('','direct'))
        THEN 'Partners'

        /* SEO por URL/INSTI (google/bing/yahoo + organic + match en inputs) */
        WHEN s.last_source_lc IN ('yahoo','google','bing')
             AND s.last_medium_lc = 'organic'
             AND (s.url_team IS NOT NULL OR s.insti_team IS NOT NULL)
        THEN COALESCE(s.url_team, s.insti_team)

        /* AI fuentes explícitas → owner por URL/INSTI si existe; si no, cae a Organic abajo */
        WHEN s.last_source_lc IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
             AND (s.url_team IS NOT NULL OR s.insti_team IS NOT NULL)
        THEN COALESCE(s.url_team, s.insti_team)

        /* Communications / Performance desde UTM */
        WHEN s.source_mkt = 'Communications' THEN 'Communications'
        WHEN s.source_mkt = 'Performance'
             AND s.last_source_lc IN ('google','bing')
             AND POSITION('-brand' IN s.last_campaign_lc) > 0
        THEN 'Performance Brand'
        WHEN s.source_mkt = 'Performance' THEN 'Performance No Brand'

        /* ChatGPT textual como Organic (igual que en stores) */
        WHEN POSITION('chatgpt' IN s.last_source_lc) > 0
        THEN 'Organic'

        /* Affiliates por medium o por path de partners */
        WHEN s.last_medium_lc = 'affiliates'
           OR POSITION('/partners/' IN s.path_clean) > 0
        THEN 'Affiliates'

        /* Fallbacks por URL/INSTI (sin source) */
        WHEN (s.last_source_lc = '')
             AND (s.url_team IS NOT NULL OR s.insti_team IS NOT NULL)
        THEN COALESCE(s.url_team, s.insti_team)

        /* Direct genérico (direct-like): source ''/direct y medium ''/direct */
        WHEN (s.last_source_lc IN ('','direct'))
         AND (s.last_medium_lc IN ('','direct'))
        THEN 'Direct'

        /* Último recurso */
        WHEN s.source_mkt IS NULL THEN 'Others'
        ELSE s.source_mkt
    END AS mkt_source,

    /* ===== MKT SUBTEAM ===== */
    CASE
        /* Performance Google pMax */
        WHEN s.source_mkt = 'Performance'
             AND s.last_source_lc = 'google'
             AND POSITION('max-perf' IN s.last_campaign_lc) > 0
        THEN 'Google pMax'

        /* Performance/Product Marketing: subteam por campaña */
        WHEN s.source_mkt = 'Performance'
             AND s.last_source_lc IN ('google','bing')
             AND s.utm_campaign_cam IS NOT NULL
             AND POSITION(s.utm_campaign_cam IN s.last_campaign_lc) > 0
        THEN s.subteam_cam

        WHEN s.source_mkt = 'Product Marketing'
             AND s.utm_campaign_cam IS NOT NULL
             AND POSITION(s.utm_campaign_cam IN s.last_campaign_lc) > 0
        THEN s.subteam_cam

        /* AI explícito: source chatgpt.com + medium vacío */
        WHEN s.last_source_lc = 'chatgpt.com'
             AND (s.last_medium_lc = '' OR s.last_medium_lc IS NULL)
        THEN 'AI'

        /* UTM subteam directo si existe */
        WHEN s.utm_subteam IS NOT NULL
        THEN s.utm_subteam

        /* Subteam por URL/INSTI */
        WHEN s.url_subteam   IS NOT NULL THEN s.url_subteam
        WHEN s.insti_subteam IS NOT NULL THEN s.insti_subteam

        /* Affiliates detectado por medium/path */
        WHEN (s.last_medium_lc = 'affiliates'
           OR POSITION('/partners/' IN s.path_clean) > 0)
        THEN 'Affiliates'

        ELSE mkt_source
    END AS mkt_subteam,

    /* ===== insti_page_groups ===== */
    CASE
      WHEN (
             s.env_lc IN ('insti','partners','next')
             OR (
                  s.landing_page_lc IN (
                    'https://www.nuvemshop.com.br/',
                    'https://www.nuvemshop.com.br/vender/online/',
                    'https://www.nuvemshop.com.br/vender/online',
                    'https://www.tiendanube.com/',
                    'https://www.tiendanube.com/mx',
                    'https://www.tiendanube.com/mx/',
                    'https://www.tiendanube.com/cl',
                    'https://www.tiendanube.com/cl/',
                    'https://www.tiendanube.com/co',
                    'https://www.tiendanube.com/co/'
                  )
                  OR REGEXP_LIKE(
                       s.path_clean,
                       '^/(site|loja-virtual|compare|plano-gratis|planos-e-precos|planes-y-precios|compara|tienda-gratis|vender/online|vender|crear-mi-tienda-online|login|recuperar-contrasena|nuvem-envio|nuvem-pago|nuvem-pay|solucoes|soluciones|next|ecossistema|parceiros|ecosistema|socios|asociados|loja-layouts-nuvem|tienda-disenos-nube|funcionalidades|eventos|dropshipping|especialistas-nube|evolucion)(/|$)'
                     )
                )
           )
       AND COALESCE(s.type_of_page,'') <> 'Content Pages'
       AND (
             COALESCE(s.total_trials,0) > 0
             OR (
                  POSITION('/admin' IN s.path_clean) = 0
              AND POSITION('/facebook/facebook-business-extension' IN s.path_clean) = 0
              AND POSITION('admin'  IN s.last_source_lc) = 0
              AND POSITION('awareness' IN s.last_campaign_lc) = 0
                )
           )
      THEN
        CASE
          WHEN s.landing_page_lc IN (
                 'https://www.nuvemshop.com.br/',
                 'https://www.nuvemshop.com.br/vender/online',
                 'https://www.nuvemshop.com.br/vender/online/',
                 'https://www.tiendanube.com/',
                 'https://www.tiendanube.com/mx',
                 'https://www.tiendanube.com/mx/',
                 'https://www.tiendanube.com/cl',
                 'https://www.tiendanube.com/cl/',
                 'https://www.tiendanube.com/co',
                 'https://www.tiendanube.com/co/'
               )
            OR REGEXP_LIKE(s.path_clean, '^/vender/online(/|$)')
          THEN 'Home'

          WHEN POSITION('/partners'                  IN s.path_clean) > 0 THEN 'Afiliados'
          WHEN POSITION('/loja-aplicativos-nuvem'   IN s.path_clean) > 0
            OR POSITION('/tienda-aplicaciones-nube' IN s.path_clean) > 0 THEN 'Apps'
          WHEN POSITION('/canais'                   IN s.path_clean) > 0
            OR POSITION('/canales'                  IN s.path_clean) > 0
            OR POSITION('/empreendedores'           IN s.path_clean) > 0
            OR POSITION('/emprendedores'            IN s.path_clean) > 0 THEN 'Canais'
          WHEN POSITION('/midia/companhia'          IN s.path_clean) > 0
            OR POSITION('/midia/equipe'             IN s.path_clean) > 0
            OR POSITION('/midia/imprensa'           IN s.path_clean) > 0
            OR POSITION('/midia/nuvem-na-midia/nuvem-shop-lanca-primeiro-aplicativo-mcommerce-brasil' IN s.path_clean) > 0 THEN 'Companhia'
          WHEN POSITION('/dropshipping'             IN s.path_clean) > 0 THEN 'Dropshipping'
          WHEN POSITION('/eventos'                  IN s.path_clean) > 0 THEN 'Eventos'
          WHEN POSITION('/funcionalidades'          IN s.path_clean) > 0 THEN 'Funcionalidades'
          WHEN POSITION('/loja-layouts-nuvem'       IN s.path_clean) > 0
            OR POSITION('/tienda-disenos-nube'      IN s.path_clean) > 0 THEN 'Layouts'
          WHEN POSITION('/login'                    IN s.path_clean) > 0
            OR POSITION('/recuperar-contrasena'     IN s.path_clean) > 0 THEN 'Login'
          WHEN POSITION('/loja-virtual'             IN s.path_clean) > 0 THEN 'Loja Virtual'
          WHEN POSITION('/monte-sua-loja-virtual'   IN s.path_clean) > 0 THEN 'Monte sua loja'
          WHEN POSITION('/next'                     IN s.path_clean) > 0 THEN 'Next'
          WHEN POSITION('/ecossistema'              IN s.path_clean) > 0
            OR POSITION('/parceiros'                IN s.path_clean) > 0
            OR POSITION('/ecosistema'               IN s.path_clean) > 0
            OR POSITION('/socios'                   IN s.path_clean) > 0
            OR POSITION('/asociados'                IN s.path_clean) > 0 THEN 'Parceiros / Socios'
          WHEN POSITION('/site'                     IN s.path_clean) > 0
            OR POSITION('/abrir-mi-tiendanube'      IN s.path_clean) > 0
            OR POSITION('/abrir-tu-tiendanube'      IN s.path_clean) > 0 THEN 'Performance'
          WHEN POSITION('/compare'                  IN s.path_clean) > 0
            OR POSITION('/plano-gratis'             IN s.path_clean) > 0
            OR POSITION('/planos-e-precos'          IN s.path_clean) > 0
            OR POSITION('/planes-y-precios'         IN s.path_clean) > 0
            OR POSITION('/compara'                  IN s.path_clean) > 0
            OR POSITION('/tienda-gratis'            IN s.path_clean) > 0 THEN 'Planos / Planes'
          WHEN POSITION('/nuvem-envio'              IN s.path_clean) > 0
            OR POSITION('/nuvem-pago'               IN s.path_clean) > 0
            OR POSITION('/nuvem-pay'                IN s.path_clean) > 0
            OR POSITION('/solucoes'                 IN s.path_clean) > 0
            OR POSITION('/soluciones'               IN s.path_clean) > 0 THEN 'Produto'
          WHEN POSITION('/termos'                   IN s.path_clean) > 0
            OR POSITION('/politica-de-privacidade'  IN s.path_clean) > 0
            OR POSITION('/politica-de-cookies'      IN s.path_clean) > 0
            OR POSITION('/regulamento-lojas-nuvem'  IN s.path_clean) > 0 THEN 'Termos'
          WHEN POSITION('/crear-mi-tienda-online'   IN s.path_clean) > 0 THEN 'Crear tienda'
          WHEN POSITION('/especialistas-nube'       IN s.path_clean) > 0 THEN 'Especialistas'
          WHEN POSITION('/evolucion'                IN s.path_clean) > 0 THEN 'Evolución'
          /* --- VENDER general, EXCLUYENDO vender/online --- */
          WHEN POSITION('/vender' IN s.path_clean) > 0
           AND POSITION('/vender/online' IN s.path_clean) = 0
          THEN 'Vender'
          ELSE 'Other'
        END
      ELSE 'Other'
    END AS insti_page_groups,

    /* Organic results (aux) */
    CASE 
        WHEN s.last_medium_lc = 'organic' THEN 'Organic'
        ELSE 'Other'
    END AS organic_results
FROM insti_pages_enriched s




