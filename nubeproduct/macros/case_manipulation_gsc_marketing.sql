{% macro classify_subteam_from_url(url_column) %}
    CASE
        WHEN instr({{ url_column }}, '/blog') > 0 THEN 'Blog'
        WHEN instr({{ url_column }}, '/banners') > 0
          OR instr({{ url_column }}, '/e-books') > 0
          OR instr({{ url_column }}, '/ebooks') > 0
          OR instr({{ url_column }}, '/recursos') > 0
          OR instr({{ url_column }}, '/materiais') > 0
          OR instr({{ url_column }}, 'materiais.nuvemshop.com.br') > 0
          OR instr({{ url_column }}, 'recursos.tiendanube.com') > 0
          THEN 'Downloadables'
        WHEN instr({{ url_column }}, '/ferramentas') > 0
          OR instr({{ url_column }}, '/herramientas') > 0
          OR instr({{ url_column }}, 'creadordebanners.com') > 0
          OR instr({{ url_column }}, 'creadordelogos.com.ar') > 0
          OR instr({{ url_column }}, 'creadordelogos.com.mx') > 0
          OR instr({{ url_column }}, 'criadordebanner.com') > 0
          OR instr({{ url_column }}, 'criadordelogo.com.br') > 0
          OR instr({{ url_column }}, 'fornecedoresdropshipping.com') > 0
          OR instr({{ url_column }}, 'nuv.link') > 0
          OR instr({{ url_column }}, 'paletadecolores.com.ar') > 0
          OR instr({{ url_column }}, 'paletadecolores.com.mx') > 0
          OR instr({{ url_column }}, 'paletadecores.com') > 0
          THEN 'Tools'
        WHEN instr({{ url_column }}, 'trilhas.nuvemshop.com.br') > 0
          OR instr({{ url_column }}, '/trilhas') > 0
          OR instr({{ url_column }}, '/cursos-ecommerce') > 0
          OR instr({{ url_column }}, '/ecommerce-por-expertos') > 0
          OR instr({{ url_column }}, '/universidade') > 0
          THEN 'Trilhas'
        WHEN instr({{ url_column }}, '/universidad') > 0 THEN 'Universidad'
        ELSE 'Otros'
    END
{% endmacro %}

{% macro classify_country(full_url_col, date_col, country_name_col) %}
    CASE
        WHEN instr({{ full_url_col }}, 'nuvemshop') > 0
          OR instr({{ full_url_col }}, '.br') > 0
          OR instr({{ full_url_col }}, 'fornecedoresdropshipping.com') > 0
          OR instr({{ full_url_col }}, 'nuv.link') > 0
          THEN 'BR'
        ELSE
            CASE
                WHEN {{ date_col }} <= DATE '2024-09-07' THEN
                    CASE
                        WHEN instr({{ full_url_col }}, '/mx/') > 0 THEN 'MX'
                        WHEN instr({{ full_url_col }}, '/co/') > 0 THEN 'CO'
                        WHEN instr({{ full_url_col }}, '/cl/') > 0 THEN 'CL'
                        ELSE 'AR'
                    END
                ELSE
                    CASE
                        WHEN {{ country_name_col }} LIKE '%Mexico%' THEN 'MX'
                        WHEN {{ country_name_col }} LIKE '%Colombia%' THEN 'CO'
                        WHEN {{ country_name_col }} LIKE '%Chile%' THEN 'CL'
                        WHEN {{ country_name_col }} LIKE '%Argentina%' THEN 'AR'
                        ELSE 'Otros'
                    END
            END
    END
{% endmacro %}
