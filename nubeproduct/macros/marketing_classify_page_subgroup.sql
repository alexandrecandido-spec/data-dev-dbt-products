{% macro marketing_classify_page_subgroup(page_group_col, input_subteam_col, full_url_col, path_col, domain_col) %}
    CASE
        -- Caso A: Inputs (La Fuente de la Verdad para Content Hub)
        WHEN {{ input_subteam_col }} IS NOT NULL THEN {{ input_subteam_col }}

        -- Caso B: Mapeos Directos por Grupo
        WHEN {{ page_group_col }} = 'Launch' THEN 'Launch'
        WHEN {{ page_group_col }} = 'Partners' THEN 'Partners'
        WHEN {{ page_group_col }} = 'Affiliates' THEN 'Affiliates'
        WHEN {{ page_group_col }} = 'Help' THEN 'Help Center'
        
        -- Caso C: Platform (Desglose Técnico vs Admin)
        WHEN {{ page_group_col }} = 'Platform' THEN 
            CASE
                WHEN POSITION('/admin/' IN {{ path_col }}) > 0 OR POSITION('/administracion/' IN {{ path_col }}) > 0 THEN 'Admin'
                WHEN POSITION('docs.' IN {{ domain_col }}) > 0 THEN 'Tech Docs'
                WHEN POSITION('dev.' IN {{ domain_col }}) > 0 THEN 'Developers'
                WHEN POSITION('nimbus.' IN {{ domain_col }}) > 0 THEN 'Design System'
                WHEN POSITION('pdv.' IN {{ domain_col }}) > 0 THEN 'POS'
                WHEN POSITION('cdn.' IN {{ domain_col }}) > 0 THEN 'CDN'
                WHEN POSITION('reports.' IN {{ domain_col }}) > 0 THEN 'Reports'
                ELSE 'Tech Services' -- Fallback para apis, checkouts internos, etc.
            END

        -- Caso D: Content Hub (Fallback Residual)
        WHEN {{ page_group_col }} = 'Content Hub' THEN 'Downloadables'

        -- Caso E: INSTI - Lógica Detallada Completa
        WHEN {{ page_group_col }} = 'Insti' THEN
            CASE
                -- 1. Subdominios específicos 
                WHEN POSITION('novedades.' IN {{ domain_col }}) > 0 THEN 'Novedades'
                WHEN POSITION('comunidad.' IN {{ domain_col }}) > 0 THEN 'Comunidad'
                WHEN POSITION('experts.' IN {{ domain_col }}) > 0 OR POSITION('especialistas.' IN {{ domain_col }}) > 0 THEN 'Especialistas'
                WHEN POSITION('status.' IN {{ domain_col }}) > 0 THEN 'Status'
                WHEN POSITION('site.' IN {{ domain_col }}) > 0 THEN 'Microsites'
                WHEN POSITION('instagram.' IN {{ domain_col }}) > 0 THEN 'LinkBio'

                -- 2. Homes
                WHEN {{ full_url_col }} IN (
                    'https://www.nuvemshop.com.br/', 'https://www.nuvemshop.com.br/vender/online', 'https://www.nuvemshop.com.br/vender/online/',
                    'https://www.tiendanube.com/', 'https://www.tiendanube.com/mx', 'https://www.tiendanube.com/mx/',
                    'https://www.tiendanube.com/cl', 'https://www.tiendanube.com/cl/',
                    'https://www.tiendanube.com/co', 'https://www.tiendanube.com/co/'
                ) 
                OR REGEXP_LIKE({{ path_col }}, '^/vender/online(/|$)') THEN 'Home'

                -- 3. Reglas por Path 
                WHEN POSITION('/partners' IN {{ path_col }}) > 0 THEN 'Afiliados'
                WHEN POSITION('/loja-aplicativos-nuvem' IN {{ path_col }}) > 0 OR POSITION('/tienda-aplicaciones-nube' IN {{ path_col }}) > 0 THEN 'Apps'
                WHEN REGEXP_LIKE({{ path_col }}, '/(canais|canales|empreendedores|emprendedores)') THEN 'Canais'
                WHEN REGEXP_LIKE({{ path_col }}, '/(midia|imprensa|companhia|equipe)') THEN 'Companhia'
                WHEN POSITION('/dropshipping' IN {{ path_col }}) > 0 THEN 'Dropshipping'
                WHEN POSITION('/eventos' IN {{ path_col }}) > 0 THEN 'Eventos'
                WHEN POSITION('/funcionalidades' IN {{ path_col }}) > 0 THEN 'Funcionalidades'
                WHEN POSITION('/loja-virtual' IN {{ path_col }}) > 0 OR POSITION('/tienda-disenos-nube' IN {{ path_col }}) > 0 THEN 'Layouts'
                WHEN POSITION('/login' IN {{ path_col }}) > 0 OR POSITION('/recuperar-contrasena' IN {{ path_col }}) > 0 THEN 'Login'
                WHEN POSITION('/monte-sua-loja-virtual' IN {{ path_col }}) > 0 THEN 'Monte sua loja'
                WHEN POSITION('/next' IN {{ path_col }}) > 0 THEN 'Next'
                WHEN REGEXP_LIKE({{ path_col }}, '/(ecossistema|parceiros|ecosistema|socios|asociados)') THEN 'Parceiros / Socios'
                WHEN REGEXP_LIKE({{ path_col }}, '/(site|abrir-mi-tiendanube|abrir-tu-tiendanube)') THEN 'Performance'
                WHEN REGEXP_LIKE({{ path_col }}, '/(compare|plano-gratis|planos-e-precos|planes-y-precios|compara|tienda-gratis)') THEN 'Planos / Planes'
                WHEN REGEXP_LIKE({{ path_col }}, '/(nuvem-envio|nuvem-pago|nuvem-pay|solucoes|soluciones)') THEN 'Produto'
                WHEN POSITION('/crear-mi-tienda-online' IN {{ path_col }}) > 0 THEN 'Crear tienda'
                WHEN POSITION('/especialistas-nube' IN {{ path_col }}) > 0 THEN 'Especialistas'
                WHEN POSITION('/evolucion' IN {{ path_col }}) > 0 THEN 'Evolución'
                WHEN POSITION('/vender' IN {{ path_col }}) > 0 THEN 'Vender'
                
                ELSE 'Other'
            END

        ELSE 'Others'
    END
{% endmacro %}