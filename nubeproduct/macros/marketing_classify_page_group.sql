{% macro marketing_classify_page_group(input_group_col, path_col, domain_col) %}
    CASE
        -- 1. Inputs de GIT (Prioridad Máxima)
        WHEN {{ input_group_col }} IS NOT NULL THEN {{ input_group_col }}

        -- 2. Content Hub (Fallback para subdominios explícitos)
        WHEN POSITION('recursos.' IN {{ domain_col }}) > 0 THEN 'Content Hub'

        -- 3. Platform: Admin + Docs + Dev + Tech
        WHEN POSITION('/admin/' IN {{ path_col }}) > 0 
          OR POSITION('/administracion/' IN {{ path_col }}) > 0 
          OR POSITION('dev.' IN {{ domain_col }}) > 0 
          OR POSITION('docs.' IN {{ domain_col }}) > 0 
          OR POSITION('nimbus.' IN {{ domain_col }}) > 0 
          OR POSITION('pdv.' IN {{ domain_col }}) > 0 
          OR POSITION('reports.' IN {{ domain_col }}) > 0 
          OR POSITION('cdn.' IN {{ domain_col }}) > 0 
          OR POSITION('api-' IN {{ domain_col }}) > 0 
          OR POSITION('services-' IN {{ domain_col }}) > 0 
          OR POSITION('checkout-' IN {{ domain_col }}) > 0 
          THEN 'Platform'

        -- 4. Help: Ayuda / Support
        WHEN POSITION('ayuda.' IN {{ domain_col }}) > 0 
          OR POSITION('atendimento.' IN {{ domain_col }}) > 0 
          OR POSITION('support.' IN {{ domain_col }}) > 0 
          THEN 'Help'

        -- 5. Affiliates
        WHEN POSITION('/partners/' IN {{ path_col }}) > 0 THEN 'Affiliates'

        -- 6. Partners Portal
        WHEN POSITION('partners.' IN {{ domain_col }}) > 0 
          OR POSITION('partners-portal' IN {{ domain_col }}) > 0 THEN 'Partners'

        -- 7. Launch
        WHEN POSITION('lancamentos.' IN {{ domain_col }}) > 0 
          OR POSITION('lanzamientos.' IN {{ domain_col }}) > 0 THEN 'Launch'

        -- 8. Fallback INSTI (SAFELIST COMPLETA)
        -- Incluye Homes y Subdominios corporativos validados
        WHEN {{ domain_col }} IN (
            -- Homes
            'tiendanube.com', 'www.tiendanube.com',
            'nuvemshop.com.br', 'www.nuvemshop.com.br',
            'tiendanube.com.ar', 'www.tiendanube.com.ar',
            'tiendanube.com.mx', 'www.tiendanube.com.mx',
            'tiendanube.com.co', 'www.tiendanube.com.co',
            'tiendanube.cl', 'www.tiendanube.cl',
            -- Subdominios
            'site.tiendanube.com', 'site.tiendanube.com.mx',
            'status.tiendanube.com', 
            'experts.tiendanube.com', 'especialistas.tiendanube.com',
            'novedades.tiendanube.com', 'comunidad.tiendanube.com',
            'instagram.tiendanube.com'
        ) THEN 'Insti'

        ELSE 'Others'
    END
{% endmacro %}