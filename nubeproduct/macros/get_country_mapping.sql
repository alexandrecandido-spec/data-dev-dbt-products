{% macro get_country_mapping(country_field, site_field) %}
  CASE 
    WHEN {{ country_field }} = 'Argentina' AND {{ site_field }} = 'https://www.tiendanube.com/' THEN 'AR'
    WHEN {{ country_field }} = 'Mexico' AND {{ site_field }} IN ('https://www.tiendanube.com.mx/', 'https://www.tiendanube.com/') THEN 'MX'
    WHEN {{ country_field }} = 'Brazil' AND {{ site_field }} = 'https://www.nuvemshop.com.br/' THEN 'BR'
    WHEN {{ country_field }} = 'Colombia' AND {{ site_field }} = 'https://www.tiendanube.com/' THEN 'CO'
    WHEN {{ country_field }} = 'Chile' AND {{ site_field }} = 'https://www.tiendanube.com/' THEN 'CL'
    WHEN {{ country_field }} = 'Peru' AND {{ site_field }} = 'https://www.tiendanube.com/' THEN 'PE'
    ELSE 'no-report' 
  END
{% endmacro %}
