{% macro marketing_country_ga4(source, landing_page, country) %}
    CASE
        WHEN {{ source }} = 'inst-br'
        OR ({{ source }} NOT LIKE '%inst%' AND {{ landing_page }} LIKE '%nuvemshop%') THEN 'BR'
        WHEN {{ source }} = 'inst-ar' THEN 'AR'
        WHEN {{ source }} = 'inst-mx' THEN 'MX'
        WHEN {{ source }} = 'inst-co' THEN 'CO'
        WHEN {{ source }} = 'inst-cl' THEN 'CL'
        WHEN {{ source }} NOT LIKE '%inst%' AND {{ country }} = 'Argentina' THEN 'AR'
        WHEN {{ source }} NOT LIKE '%inst%' AND {{ country }} = 'Mexico' THEN 'MX'
        WHEN {{ source }} NOT LIKE '%inst%' AND {{ country }} = 'Chile' THEN 'CL'
        WHEN {{ source }} NOT LIKE '%inst%' AND {{ country }} = 'Colombia' THEN 'CO'
        WHEN {{ source }} NOT LIKE '%inst%' AND {{ country }} NOT IN ('Mexico', 'Argentina', 'Chile', 'Colombia') THEN 'Other'
        ELSE {{ country }}
    END
{% endmacro %}

{% macro marketing_partner_code_ga4(page) %}
    SPLIT_PART(SPLIT_PART(SPLIT_PART(page, 'partners/', 2), '/', 1), '?', 1)
{% endmacro %}