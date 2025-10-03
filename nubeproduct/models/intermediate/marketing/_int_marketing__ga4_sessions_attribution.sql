WITH base AS (
    SELECT
        agg.*,

        /* Normalizaciones (coinciden con Stores donde aplica) */
        LOWER(REGEXP_REPLACE(agg.landing_page_domain, '^(?:https?://)?(?:www\\.)?', '')) AS domain_clean,
        LOWER(COALESCE(agg.landing_page_path, ''))                                       AS path_clean,
        LOWER(COALESCE(agg.landing_page, ''))                                            AS landing_page_lc,
        LOWER(COALESCE(agg.env, ''))                                                     AS env_lc,

        /* GA4: (none)/(not set) -> '' */
        CASE WHEN LOWER(COALESCE(agg.last_source,''))   IN ('(none)','(not set)') THEN '' ELSE LOWER(COALESCE(agg.last_source,''))   END AS last_source_lc,
        CASE WHEN LOWER(COALESCE(agg.last_medium,''))   IN ('(none)','(not set)') THEN '' ELSE LOWER(COALESCE(agg.last_medium,''))   END AS last_medium_lc,
        CASE WHEN LOWER(COALESCE(agg.last_campaign,'')) IN ('(none)','(not set)') THEN '' ELSE LOWER(COALESCE(agg.last_campaign,'')) END AS last_campaign_lc
    FROM {{ ref('marketing_ga4_sessions_aggregated') }} agg
),

/* partner_code desde /partners/<code>… */
partner_code_extracted AS (
    SELECT
        b.*,
        REGEXP_EXTRACT(b.path_clean, '^/partners/([^/?#]+)') AS partner_code
    FROM base b
),

/* URL (match más largo) */
url_enriched AS (
    SELECT
        p.*,
        u.team    AS url_team,
        u.subteam AS url_subteam,
        u.sys_audit_updated_on AS url_sys_audit_updated_on
    FROM partner_code_extracted p
    LEFT JOIN LATERAL (
        SELECT team, subteam, sys_audit_updated_on
        FROM {{ ref('marketing_inputs_attribution__url') }} u
        WHERE u.landing_page_domain = p.domain_clean
          AND POSITION(u.landing_page_path IN p.path_clean) > 0
        ORDER BY LENGTH(u.landing_page_path) DESC
        LIMIT 1
    ) u ON TRUE
),

/* Insti (match más largo) */
insti_enriched AS (
    SELECT
        u.*,
        i.team    AS insti_team,
        i.subteam AS insti_subteam,
        i.sys_audit_updated_on AS insti_sys_audit_updated_on
    FROM url_enriched u
    LEFT JOIN LATERAL (
        SELECT team, subteam, sys_audit_updated_on
        FROM {{ ref('marketing_inputs_attribution__insti') }} i
        WHERE i.landing_page_domain = u.domain_clean
          AND POSITION(i.landing_page_path IN u.path_clean) > 0
        ORDER BY LENGTH(i.landing_page_path) DESC
        LIMIT 1
    ) i ON TRUE
),

/* UTM (source/medium → source_mkt/subteam) */
utm_enriched AS (
    SELECT
        i.*,
        ut.source_mkt,
        ut.subteam AS utm_subteam,
        ut.sys_audit_updated_on AS utm_sys_audit_updated_on
    FROM insti_enriched i
    LEFT JOIN LATERAL (
        SELECT source_mkt, subteam, sys_audit_updated_on
        FROM {{ ref('marketing_inputs_attribution__utm') }} ut
        WHERE ut.source = i.last_source_lc
          AND ut.medium = i.last_medium_lc
        LIMIT 1
    ) ut ON TRUE
),

/* Subteam por campaña (source/medium coincidente) */
subcam_enriched AS (
    SELECT
        u.*,
        sc.subteam      AS subteam_cam,
        sc.utm_campaign AS utm_campaign_cam,
        sc.team         AS subteam_team,
        sc.sys_audit_updated_on AS subteam_sys_audit_updated_on
    FROM utm_enriched u
    LEFT JOIN LATERAL (
        SELECT team, subteam, utm_campaign, sys_audit_updated_on
        FROM {{ ref('marketing_inputs_attribution__subteam') }} sc
        WHERE sc.utm_source = u.last_source_lc
          AND sc.utm_medium = u.last_medium_lc
        LIMIT 1
    ) sc ON TRUE
),

/* Referrer (tag/fallback como en Stores) */
referrer_enriched AS (
    SELECT
        s.*,
        r.referrer AS referrer_kw,
        r.team     AS referrer_team,
        r.subteam  AS referrer_subteam,
        r.sys_audit_updated_on AS referrer_sys_audit_updated_on
    FROM subcam_enriched s
    LEFT JOIN LATERAL (
        SELECT referrer, team, subteam, sys_audit_updated_on
        FROM {{ ref('marketing_inputs_attribution__referrer') }} r
        /* en GA4 no hay referrer_domain/path estándar → matcheamos contra URL completa */
        WHERE POSITION(r.referrer IN s.path_clean) > 0
           OR POSITION(r.referrer IN s.landing_page_lc) > 0
        LIMIT 1
    ) r ON TRUE
),

/* Partner exception + affiliate classification por partner_code (como Stores) */
partners_enriched AS (
    SELECT
        r.*,
        pe.team    AS partner_team,
        pe.subteam AS partner_subteam,
        pe.sys_audit_updated_on AS partner_exception_sys_audit_updated_on,
        ac.affiliate_classification AS affiliate_type,
        ac.sys_audit_updated_on     AS affiliate_class_sys_audit_updated_on
    FROM referrer_enriched r
    LEFT JOIN {{ ref('marketing_inputs_attribution__partner_exception') }} pe
      ON pe.partner_code = r.partner_code
    LEFT JOIN {{ ref('marketing_inputs_attribution__affiliate_classification') }} ac
      ON ac.affiliate_code = r.partner_code
),

/* url_content_type = fallback URL/Insti */
content_type_enriched AS (
    SELECT
        p.*,
        COALESCE(p.url_subteam, p.insti_subteam) AS url_content_type
    FROM partners_enriched p
),

/* Type of page (mantener) */
page_type_enriched AS (
    SELECT
        s.*,
        CASE
            WHEN s.url_content_type IN ('Blog', 'Downloadables', 'Tools', 'Trilhas') THEN 'Content Pages'
            ELSE 'Other Pages'
        END AS type_of_page
    FROM content_type_enriched s
),

/* Insti pages (mantener) */
insti_pages_enriched AS (
    SELECT
        s.*,
        CASE
          WHEN (
                 s.env_lc IN ('insti','partners','next')
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
),

/* Owner (URL/Insti) */
owner_enriched AS (
    SELECT
        s.*,
        COALESCE(s.url_team, s.insti_team) AS url_owner
    FROM insti_pages_enriched s
),

/* === Paso 1: SOLO mkt_source (idéntico a Stores) === */
classified_source AS (
  SELECT
    s.*,
    CASE
      WHEN s.domain_clean IN ('partners.tiendanube.com','partners.nuvemshop.com.br')
        AND s.last_source_lc   IN ('','direct')
        AND s.last_medium_lc   IN ('','direct')
        AND s.last_campaign_lc IN ('','direct')
      THEN 'Partners'

      WHEN s.last_source_lc IN ('yahoo','google','bing')
        AND s.last_medium_lc = 'organic'
        AND (s.url_team IS NOT NULL OR s.insti_team IS NOT NULL)
      THEN COALESCE(s.url_team, s.insti_team)

      WHEN s.last_source_lc IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
        AND (s.url_team IS NOT NULL OR s.insti_team IS NOT NULL)
      THEN COALESCE(s.url_team, s.insti_team)

      WHEN POSITION('chatgpt' IN s.last_source_lc) > 0
      THEN 'Organic'

      WHEN s.source_mkt = 'Communications'
      THEN 'Communications'

      WHEN s.source_mkt = 'Performance'
           AND s.last_source_lc IN ('google','bing')
           AND POSITION('-brand' IN s.last_campaign_lc) > 0
      THEN 'Performance Brand'

      WHEN s.source_mkt = 'Performance'
      THEN 'Performance No Brand'

      WHEN s.last_source_lc = ''
        AND (s.url_team IS NOT NULL OR s.insti_team IS NOT NULL)
      THEN COALESCE(s.url_team, s.insti_team)

      WHEN s.source_mkt IS NULL
        AND (s.last_medium_lc = 'affiliates' OR POSITION('/partners/' IN s.path_clean) > 0)
      THEN 'Affiliates'

      WHEN s.source_mkt IS NULL
        AND s.partner_code IS NOT NULL
        AND s.partner_team IS NOT NULL
      THEN s.partner_team

      WHEN s.last_source_lc IN ('','direct') AND s.last_medium_lc IN ('','direct')
      THEN 'Direct'

      WHEN s.source_mkt IS NULL
      THEN 'Others'

      ELSE s.source_mkt
    END AS mkt_source
  FROM owner_enriched s
),

/* === Paso 2: mkt_subteam (fallback = mkt_source, precedencia Stores) === */
classified_final AS (
  SELECT
    cs.*,
    COALESCE(
      CASE
        /* PERFORMANCE */
        WHEN cs.mkt_source IN ('Performance Brand','Performance No Brand') THEN
          CASE
            WHEN cs.source_mkt = 'Performance'
                 AND cs.last_source_lc = 'google'
                 AND POSITION('max-perf' IN cs.last_campaign_lc) > 0
            THEN 'Google pMax'

            WHEN cs.source_mkt IN ('Performance','Product Marketing')
                 AND cs.utm_campaign_cam IS NOT NULL
                 AND POSITION(cs.utm_campaign_cam IN cs.last_campaign_lc) > 0
            THEN cs.subteam_cam

            WHEN cs.utm_subteam IS NOT NULL
            THEN cs.utm_subteam

            WHEN cs.mkt_source = 'Performance Brand'
            THEN CASE WHEN cs.last_source_lc = 'bing' THEN 'Bing Brand' ELSE 'Google Brand' END

            ELSE 'Performance No Brand'
          END

        /* PRODUCT MARKETING */
        WHEN cs.mkt_source = 'Product Marketing' THEN
          CASE
            WHEN cs.utm_campaign_cam IS NOT NULL
                 AND POSITION(cs.utm_campaign_cam IN cs.last_campaign_lc) > 0
            THEN cs.subteam_cam
            WHEN cs.utm_subteam IS NOT NULL
            THEN cs.utm_subteam
            ELSE 'Product Marketing'
          END

        /* AI (ChatGPT) + opcional Gemini via referrer_kw si existe en inputs) */
        WHEN cs.mkt_source = 'Organic' AND (
               (cs.last_source_lc = 'chatgpt.com' AND (cs.last_medium_lc = '' OR cs.last_medium_lc IS NULL))
               OR POSITION('chatgpt' IN cs.last_source_lc) > 0
               OR cs.referrer_kw = 'gemini.google.com'
             )
        THEN 'AI'

        /* Affiliates con tipificación */
        WHEN cs.mkt_source = 'Affiliates'
        THEN COALESCE(cs.affiliate_type, 'Affiliates')

        /* Owners/referrer/partner SOLO si coincide el owner con mkt_source */
        WHEN cs.mkt_source = cs.subteam_team
             AND cs.subteam_cam IS NOT NULL
             AND cs.utm_campaign_cam IS NOT NULL
             AND POSITION(cs.utm_campaign_cam IN cs.last_campaign_lc) > 0
        THEN cs.subteam_cam

        WHEN cs.mkt_source = cs.url_team   AND cs.url_subteam   IS NOT NULL THEN cs.url_subteam
        WHEN cs.mkt_source = cs.insti_team AND cs.insti_subteam IS NOT NULL THEN cs.insti_subteam
        WHEN cs.mkt_source = cs.referrer_team AND cs.referrer_subteam IS NOT NULL THEN cs.referrer_subteam
        WHEN cs.mkt_source = cs.partner_team  AND cs.partner_subteam  IS NOT NULL THEN cs.partner_subteam

        /* SIN UTM source_mkt → igual que Stores: cae en mkt_source */
        WHEN cs.source_mkt IS NULL THEN cs.mkt_source

        /* Con utm_subteam explícito → úsalo */
        WHEN cs.utm_subteam IS NOT NULL THEN cs.utm_subteam

        ELSE cs.mkt_source
      END,
      cs.mkt_source
    ) AS mkt_subteam
  FROM classified_source cs
),

/* insti_page_groups + organic_results (mantener) */
insti_groups AS (
    SELECT
      s.*,
      CASE
        WHEN (
               s.env_lc IN ('insti','partners','next')
               OR (
                    s.landing_page_lc IN (
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
            WHEN POSITION('/partners' IN s.path_clean) > 0 THEN 'Afiliados'
            WHEN POSITION('/loja-aplicativos-nuvem'   IN s.path_clean) > 0
              OR POSITION('/tienda-aplicaciones-nube' IN s.path_clean) > 0 THEN 'Apps'
            WHEN POSITION('/canais' IN s.path_clean) > 0 OR POSITION('/canales' IN s.path_clean) > 0
              OR POSITION('/empreendedores' IN s.path_clean) > 0 OR POSITION('/emprendedores' IN s.path_clean) > 0 THEN 'Canais'
            WHEN POSITION('/midia/companhia' IN s.path_clean) > 0
              OR POSITION('/midia/equipe' IN s.path_clean) > 0
              OR POSITION('/midia/imprensa' IN s.path_clean) > 0
              OR POSITION('/midia/nuvem-na-midia/nuvem-shop-lanca-primeiro-aplicativo-mcommerce-brasil' IN s.path_clean) > 0 THEN 'Companhia'
            WHEN POSITION('/dropshipping' IN s.path_clean) > 0 THEN 'Dropshipping'
            WHEN POSITION('/eventos' IN s.path_clean) > 0 THEN 'Eventos'
            WHEN POSITION('/funcionalidades' IN s.path_clean) > 0 THEN 'Funcionalidades'
            WHEN POSITION('/loja-layouts-nuvem' IN s.path_clean) > 0
              OR POSITION('/tienda-disenos-nube' IN s.path_clean) > 0 THEN 'Layouts'
            WHEN POSITION('/login' IN s.path_clean) > 0 OR POSITION('/recuperar-contrasena' IN s.path_clean) > 0 THEN 'Login'
            WHEN POSITION('/loja-virtual' IN s.path_clean) > 0 THEN 'Loja Virtual'
            WHEN POSITION('/monte-sua-loja-virtual' IN s.path_clean) > 0 THEN 'Monte sua loja'
            WHEN POSITION('/next' IN s.path_clean) > 0 THEN 'Next'
            WHEN POSITION('/ecossistema' IN s.path_clean) > 0 OR POSITION('/parceiros' IN s.path_clean) > 0
              OR POSITION('/ecosistema' IN s.path_clean) > 0 OR POSITION('/socios' IN s.path_clean) > 0
              OR POSITION('/asociados' IN s.path_clean) > 0 THEN 'Parceiros / Socios'
            WHEN POSITION('/site' IN s.path_clean) > 0
              OR POSITION('/abrir-mi-tiendanube' IN s.path_clean) > 0
              OR POSITION('/abrir-tu-tiendanube' IN s.path_clean) > 0 THEN 'Performance'
            WHEN POSITION('/compare' IN s.path_clean) > 0 OR POSITION('/plano-gratis' IN s.path_clean) > 0
              OR POSITION('/planos-e-precos' IN s.path_clean) > 0 OR POSITION('/planes-y-precios' IN s.path_clean) > 0
              OR POSITION('/compara' IN s.path_clean) > 0 OR POSITION('/tienda-gratis' IN s.path_clean) > 0 THEN 'Planos / Planes'
            WHEN POSITION('/nuvem-envio' IN s.path_clean) > 0 OR POSITION('/nuvem-pago' IN s.path_clean) > 0
              OR POSITION('/nuvem-pay' IN s.path_clean) > 0 OR POSITION('/solucoes' IN s.path_clean) > 0
              OR POSITION('/soluciones' IN s.path_clean) > 0 THEN 'Produto'
            WHEN POSITION('/termos' IN s.path_clean) > 0
              OR POSITION('/politica-de-privacidade' IN s.path_clean) > 0
              OR POSITION('/politica-de-cookies' IN s.path_clean) > 0
              OR POSITION('/regulamento-lojas-nuvem' IN s.path_clean) > 0 THEN 'Termos'
            WHEN POSITION('/crear-mi-tienda-online' IN s.path_clean) > 0 THEN 'Crear tienda'
            WHEN POSITION('/especialistas-nube' IN s.path_clean) > 0 THEN 'Especialistas'
            WHEN POSITION('/evolucion' IN s.path_clean) > 0 THEN 'Evolución'
            WHEN POSITION('/vender' IN s.path_clean) > 0 AND POSITION('/vender/online' IN s.path_clean) = 0 THEN 'Vender'
            ELSE 'Other'
          END
        ELSE 'Other'
      END AS insti_page_groups,

      CASE WHEN s.last_medium_lc = 'organic' THEN 'Organic' ELSE 'Other' END AS organic_results
    FROM classified_final s
),

/* Tags y change_timestamp_incremental (para incrementalidad en DP) */
inputs_and_audit AS (
    SELECT
      g.*,

      TRIM(BOTH ',' FROM CONCAT_WS(',',
          CASE WHEN g.source_mkt IS NOT NULL                    THEN 'utm' END,
          CASE WHEN g.subteam_cam IS NOT NULL                   THEN 'subteam' END,
          CASE WHEN g.referrer_kw IS NOT NULL                   THEN 'referrer' END,
          CASE WHEN g.url_team IS NOT NULL                      THEN 'url' END,
          CASE WHEN g.insti_team IS NOT NULL                    THEN 'insti' END,
          CASE WHEN g.partner_team IS NOT NULL                  THEN 'partner_exception' END,
          CASE WHEN g.affiliate_type IS NOT NULL                THEN 'affiliate_classification' END,
          CASE WHEN g.partner_code IS NOT NULL                  THEN 'partner_code' END
      )) AS input_sources,

      GREATEST(
        COALESCE(g.utm_sys_audit_updated_on,               TIMESTAMP '1900-01-01'),
        COALESCE(g.subteam_sys_audit_updated_on,           TIMESTAMP '1900-01-01'),
        COALESCE(g.referrer_sys_audit_updated_on,          TIMESTAMP '1900-01-01'),
        COALESCE(g.url_sys_audit_updated_on,               TIMESTAMP '1900-01-01'),
        COALESCE(g.insti_sys_audit_updated_on,             TIMESTAMP '1900-01-01'),
        COALESCE(g.partner_exception_sys_audit_updated_on, TIMESTAMP '1900-01-01'),
        COALESCE(g.affiliate_class_sys_audit_updated_on,   TIMESTAMP '1900-01-01')
      ) AS change_timestamp_incremental
    FROM insti_groups g
)

SELECT *
FROM inputs_and_audit


