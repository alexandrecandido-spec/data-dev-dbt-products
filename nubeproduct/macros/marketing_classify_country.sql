-- para clasificar paises basado en dominio, path y nombre de país desde GSC y GA4
{% macro marketing_classify_country(domain_col, path_col, country_name_col, date_col) %}
    CASE
        -- ==========================================================
        -- LÓGICA HISTÓRICA (Hasta 7 Sep 2024)
        -- ==========================================================
        WHEN {{ date_col }} <= DATE '2024-09-07' THEN
            CASE
                -- 1. Prioridad URL (Paths Viejos)
                WHEN POSITION('/mx/' IN {{ path_col }}) > 0 THEN 'MX'
                WHEN POSITION('/co/' IN {{ path_col }}) > 0 THEN 'CO'
                WHEN POSITION('/cl/' IN {{ path_col }}) > 0 THEN 'CL'
                
                -- 2. Fallback Geo (Nombres en Inglés/Español por GSC)
                WHEN POSITION('mexico'    IN LOWER({{ country_name_col }})) > 0 THEN 'MX'
                WHEN POSITION('colombia'  IN LOWER({{ country_name_col }})) > 0 THEN 'CO'
                WHEN POSITION('chile'     IN LOWER({{ country_name_col }})) > 0 THEN 'CL'
                WHEN POSITION('argentina' IN LOWER({{ country_name_col }})) > 0 THEN 'AR'
                
                -- 3. Brasil (Siempre fuerte por dominio)
                WHEN POSITION('nuvemshop' IN {{ domain_col }}) > 0 
                  OR POSITION('.br' IN {{ domain_col }}) > 0 THEN 'BR'

                ELSE 'AR' -- Default histórico solía ser AR
            END

        -- ==========================================================
        -- LÓGICA NUEVA (Desde 8 Sep 2024)
        -- ==========================================================
        ELSE
            CASE
                -- 1. Brasil Mandatorio (Inst-br equivalente)
                WHEN POSITION('nuvemshop' IN {{ domain_col }}) > 0 
                  OR POSITION('.br' IN {{ domain_col }}) > 0 THEN 'BR'

                -- 2. Tiendanube con prefijo de país (Starts With)
                --  "LIKE /mx%" verificando si la posición es 1 (al inicio del path)
                WHEN POSITION('tiendanube.com' IN {{ domain_col }}) > 0 
                     AND POSITION('/mx' IN {{ path_col }}) = 1 THEN 'MX'
                WHEN POSITION('tiendanube.com' IN {{ domain_col }}) > 0 
                     AND POSITION('/co' IN {{ path_col }}) = 1 THEN 'CO'
                WHEN POSITION('tiendanube.com' IN {{ domain_col }}) > 0 
                     AND POSITION('/cl' IN {{ path_col }}) = 1 THEN 'CL'

                -- 3. Fallback Geo Estricto (Names exactos o seguros)
                WHEN LOWER({{ country_name_col }}) IN ('argentina', 'ar') THEN 'AR'
                WHEN LOWER({{ country_name_col }}) IN ('mexico', 'mx', 'méxico') THEN 'MX'
                WHEN LOWER({{ country_name_col }}) IN ('chile', 'cl')     THEN 'CL'
                WHEN LOWER({{ country_name_col }}) IN ('colombia', 'co')  THEN 'CO'
                WHEN LOWER({{ country_name_col }}) IN ('brazil', 'br', 'brasil') THEN 'BR'

                ELSE 'Others'
            END
    END
{% endmacro %}