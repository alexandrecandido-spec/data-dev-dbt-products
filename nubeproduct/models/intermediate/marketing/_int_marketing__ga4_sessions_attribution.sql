WITH base AS (
    SELECT
        agg.*,
        REGEXP_REPLACE(agg.landing_page_domain, '^(?:https?://)?(?:www\\.)?', '') AS domain_clean,
        agg.landing_page_path                                                      AS path_clean
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
        u.source_mkt,
        u.subteam AS utm_subteam
    FROM insti_enriched i
    LEFT JOIN LATERAL (
        SELECT source_mkt, subteam
        FROM {{ ref('marketing_inputs_attribution__utm') }} u
        WHERE u.source = i.last_source
          AND u.medium = i.last_medium
        LIMIT 1
    ) u ON TRUE
),

/* Subteam por campaña */
subcam_enriched AS (
    SELECT
        u.*,
        s.subteam      AS subteam_cam,
        s.utm_campaign AS utm_campaign_cam
    FROM utm_enriched u
    LEFT JOIN LATERAL (
        SELECT subteam, utm_campaign
        FROM {{ ref('marketing_inputs_attribution__subteam') }} s
        WHERE s.utm_source = u.last_source
          AND s.utm_medium = u.last_medium
        LIMIT 1
    ) s ON TRUE
),

/* url_content_type = fallback de subteam URL / insti */
content_type_enriched AS (
    SELECT
        s.*,
        COALESCE(s.url_subteam, s.insti_subteam) AS url_content_type
    FROM subcam_enriched s
),

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
                 LOWER(TRIM(COALESCE(s.env,''))) IN ('insti','partners','next')
                 /* B) URLs exactas o paths permitidos */
                 OR (
                      LOWER(COALESCE(s.landing_page,'')) IN (
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
                           LOWER(COALESCE(s.landing_page_path,'')),
                           '^/(site|loja-virtual|compare|plano-gratis|planos-e-precos|planes-y-precios|compara|tienda-gratis|vender/online|crear-mi-tienda-online|login|recuperar-contrasena|nuvem-envio|nuvem-pago|nuvem-pay|solucoes|soluciones|next|ecossistema|parceiros|ecosistema|socios|asociados|loja-layouts-nuvem|tienda-disenos-nube|funcionalidades|eventos|dropshipping|especialistas-nube|evolucion|vender)(/|$)'
                         )
                    )
               )
           AND COALESCE(s.type_of_page,'') <> 'Content Pages'
           AND (
                 COALESCE(s.total_trials,0) > 0
                 OR (
                      POSITION('/admin' IN LOWER(COALESCE(s.landing_page_path,''))) = 0
                  AND POSITION('/facebook/facebook-business-extension' IN LOWER(COALESCE(s.landing_page_path,''))) = 0
                  AND POSITION('admin' IN LOWER(COALESCE(s.last_source,''))) = 0
                  AND POSITION('awareness' IN LOWER(COALESCE(s.last_campaign,''))) = 0
                    )
               )
          THEN 'Insti'
          ELSE 'Other'
        END AS insti_pages
    FROM page_type_enriched s
)

SELECT
    s.* EXCEPT(url_team, url_subteam, insti_team, insti_subteam, source_mkt, utm_subteam, subteam_cam, utm_campaign_cam),

    /* URL owner */
    COALESCE(s.url_team, s.insti_team) AS url_owner,

    /* type_of_page ya viene calculado en la CTE previa */
    s.type_of_page AS type_of_page,

    /* MKT SOURCE  */
    CASE
        WHEN s.last_source = 'direct'
             AND s.last_medium IS NULL
             AND s.last_campaign IS NULL
             AND s.domain_clean IN ('partners.tiendanube.com', 'partners.nuvemshop.com.br')
          THEN 'Partners'
        WHEN s.last_source IN ('yahoo','google','bing')
             AND s.last_medium = 'organic'
             AND (s.url_team IS NOT NULL OR s.insti_team IS NOT NULL)
          THEN COALESCE(s.url_team, s.insti_team)
        WHEN s.source_mkt = 'Communications' THEN 'Communications'
        WHEN s.source_mkt = 'Performance'
             AND s.last_source IN ('google','bing')
             AND POSITION('-brand' IN s.last_campaign) > 0
          THEN 'Performance Brand'
        WHEN s.source_mkt = 'Performance' THEN 'Performance No Brand'
        WHEN (s.last_source = '' OR s.last_source IS NULL)
             AND s.last_medium = 'direct' THEN 'Direct'
        WHEN s.source_mkt IS NULL THEN 'Others'
        ELSE s.source_mkt
    END AS mkt_source,

    /* MKT SUBTEAM */
    CASE
        WHEN s.source_mkt = 'Performance'
             AND s.last_source = 'google'
             AND POSITION('max-perf' IN s.last_campaign) > 0
          THEN 'Google pMax'
        WHEN s.source_mkt = 'Performance'
             AND s.last_source IN ('google','bing')
             AND POSITION(s.utm_campaign_cam IN s.last_campaign) > 0
          THEN s.subteam_cam
        WHEN s.source_mkt = 'Product Marketing'
             AND POSITION(s.utm_campaign_cam IN s.last_campaign) > 0
          THEN s.subteam_cam
        WHEN s.last_source = 'chatgpt.com'
             AND (s.last_medium = '' OR s.last_medium IS NULL)
          THEN 'AI'
        WHEN s.utm_subteam IS NOT NULL THEN s.utm_subteam
        WHEN s.url_subteam IS NOT NULL THEN s.url_subteam
        WHEN s.insti_subteam IS NOT NULL THEN s.insti_subteam
        ELSE mkt_source
    END AS mkt_subteam,

    /* insti_page_groups */
    CASE
      WHEN (
             /* A) env institucional */
             LOWER(TRIM(COALESCE(s.env,''))) IN ('insti','partners','next')
             /* B) URLs exactas o paths permitidos */
             OR (
                  LOWER(COALESCE(s.landing_page,'')) IN (
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
                  OR REGEXP_LIKE(
                       LOWER(COALESCE(s.landing_page_path,'')),
                       '^/(site|loja-virtual|compare|plano-gratis|planos-e-precos|planes-y-precios|compara|tienda-gratis|vender/online|vender|crear-mi-tienda-online|login|recuperar-contrasena|nuvem-envio|nuvem-pago|nuvem-pay|solucoes|soluciones|next|ecossistema|parceiros|ecosistema|socios|asociados|loja-layouts-nuvem|tienda-disenos-nube|funcionalidades|eventos|dropshipping|especialistas-nube|evolucion)(/|$)'
                     )
                )
           )
       AND COALESCE(s.type_of_page,'') <> 'Content Pages'
       AND (
             COALESCE(s.total_trials,0) > 0
             OR (
                  POSITION('/admin' IN LOWER(COALESCE(s.landing_page_path,''))) = 0
              AND POSITION('/facebook/facebook-business-extension' IN LOWER(COALESCE(s.landing_page_path,''))) = 0
              AND POSITION('admin' IN LOWER(COALESCE(s.last_source,''))) = 0
              AND POSITION('awareness' IN LOWER(COALESCE(s.last_campaign,''))) = 0
                )
           )
      THEN
        CASE
          /* --- HOME primero: roots + vender/online --- */
          WHEN
               LOWER(COALESCE(s.landing_page,'')) IN (
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
            OR REGEXP_LIKE(LOWER(COALESCE(s.landing_page_path,'')), '^/vender/online(/|$)')
          THEN 'Home'

          WHEN POSITION('/partners'                  IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Afiliados'
          WHEN POSITION('/loja-aplicativos-nuvem'   IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/tienda-aplicaciones-nube' IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Apps'
          WHEN POSITION('/canais'                   IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/canales'                  IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/empreendedores'           IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/emprendedores'            IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Canais'
          WHEN POSITION('/midia/companhia'          IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/midia/equipe'             IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/midia/imprensa'           IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/midia/nuvem-na-midia/nuvem-shop-lanca-primeiro-aplicativo-mcommerce-brasil'
                                                 IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Companhia'
          WHEN POSITION('/dropshipping'             IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Dropshipping'
          WHEN POSITION('/eventos'                  IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Eventos'
          WHEN POSITION('/funcionalidades'          IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Funcionalidades'
          WHEN POSITION('/loja-layouts-nuvem'       IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/tienda-disenos-nube'      IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Layouts'
          WHEN POSITION('/login'                    IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/recuperar-contrasena'     IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Login'
          WHEN POSITION('/loja-virtual'             IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Loja Virtual'
          WHEN POSITION('/monte-sua-loja-virtual'   IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Monte sua loja'
          WHEN POSITION('/next'                     IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Next'
          WHEN POSITION('/ecossistema'              IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/parceiros'                IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/ecosistema'               IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/socios'                   IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/asociados'                IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Parceiros / Socios'
          WHEN POSITION('/site'                     IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/abrir-mi-tiendanube'      IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/abrir-tu-tiendanube'      IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Performance'
          WHEN POSITION('/compare'                  IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/plano-gratis'             IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/planos-e-precos'          IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/planes-y-precios'         IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/compara'                  IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/tienda-gratis'            IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Planos / Planes'
          WHEN POSITION('/nuvem-envio'              IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/nuvem-pago'               IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/nuvem-pay'                IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/solucoes'                 IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/soluciones'               IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Produto'
          WHEN POSITION('/termos'                   IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/politica-de-privacidade'  IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/politica-de-cookies'      IN LOWER(COALESCE(s.landing_page_path,''))) > 0
            OR POSITION('/regulamento-lojas-nuvem'  IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Termos'
          WHEN POSITION('/crear-mi-tienda-online'   IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Crear tienda'
          WHEN POSITION('/especialistas-nube'       IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Especialistas'
          WHEN POSITION('/evolucion'                IN LOWER(COALESCE(s.landing_page_path,''))) > 0 THEN 'Evolución'
          /* --- VENDER general, EXCLUYENDO vender/online --- */
          WHEN POSITION('/vender' IN LOWER(COALESCE(s.landing_page_path,''))) > 0
           AND POSITION('/vender/online' IN LOWER(COALESCE(s.landing_page_path,''))) = 0
          THEN 'Vender'
          ELSE 'Other'
        END
      ELSE 'Other'
    END AS insti_page_groups,

    /* Organic results */
    CASE 
        WHEN LOWER(s.last_medium) = 'organic' THEN 'Organic'
        ELSE 'Other'
    END AS organic_results

FROM insti_pages_enriched s


