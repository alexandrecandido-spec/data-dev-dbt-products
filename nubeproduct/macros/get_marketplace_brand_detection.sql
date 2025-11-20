{% macro get_marketplace_brand_detection(country_field, search_query_field) %}
CASE 
  -- PRIORITY 1: EXACT MATCHES - Nuestras marcas base (también aparecen como marketplace)
  
  -- Tiendanube base (MX, AR, CO, PE, CL)
  WHEN {{ country_field }} IN ('MX', 'AR', 'CO', 'PE', 'CL') 
    AND LOWER({{ search_query_field }}) IN ('tiendanube', 'tienda nube')
  THEN STRUCT('tiendanube' AS brand_name, 'exact' AS match_type)
  
  -- Nuvemshop base (solo BR)
  WHEN {{ country_field }} = 'BR' 
    AND LOWER({{ search_query_field }}) IN ('nuvemshop', 'nuvem shop')
  THEN STRUCT('nuvemshop' AS brand_name, 'exact' AS match_type)
  
  -- PRIORITY 2: EXACT MATCHES - Variantes con países (MX)
  WHEN {{ country_field }} = 'MX' AND LOWER({{ search_query_field }}) IN (
    'tiendanube mexico', 'tiendanube méxico', 
    'tienda nube mexico', 'tienda nube méxico'
  ) THEN STRUCT('tiendanube' AS brand_name, 'exact' AS match_type)
  
  -- PRIORITY 3: EXACT MATCHES - Con evolution (MX, AR, CO, PE, CL)
  WHEN {{ country_field }} IN ('MX', 'AR', 'CO', 'PE', 'CL') AND LOWER({{ search_query_field }}) IN (
    'tiendanube evolucion', 'tiendanube evolución', 'tiendanube evolution',
    'tienda nube evolucion', 'tienda nube evolución', 'tienda nube evolution'
  ) THEN STRUCT('tiendanube' AS brand_name, 'exact' AS match_type)
  
  -- Con next (BR)
  WHEN {{ country_field }} = 'BR' AND LOWER({{ search_query_field }}) IN (
    'nuvemshop next', 'nuvem shop next'
  ) THEN STRUCT('nuvemshop' AS brand_name, 'exact' AS match_type)
  
  -- PRIORITY 4: EXACT MATCHES - Marketplaces con normalización
  
  -- Argentina (AR)
  WHEN {{ country_field }} = 'AR' AND LOWER({{ search_query_field }}) IN ('mercado libre', 'mercadolibre')
  THEN STRUCT('mercado libre' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND LOWER({{ search_query_field }}) IN ('frávega', 'fravega')
  THEN STRUCT('frávega' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND LOWER({{ search_query_field }}) IN ('facebook marketplace')
  THEN STRUCT('facebook marketplace' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND LOWER({{ search_query_field }}) IN ('olx', 'amazon', 'aliexpress', 'ebay')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- Brasil (BR)  
  WHEN {{ country_field }} = 'BR' AND LOWER({{ search_query_field }}) IN ('mercado livre', 'mercadolivre')
  THEN STRUCT('mercado livre' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND LOWER({{ search_query_field }}) IN ('casas bahia', 'casasbahia')
  THEN STRUCT('casas bahia' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND LOWER({{ search_query_field }}) IN ('magalu', 'americanas', 'amazon', 'shopee', 'olx', 'submarino', 'netshoes', 'enjoei', 'shein', 'aliexpress')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- México (MX)
  WHEN {{ country_field }} = 'MX' AND LOWER({{ search_query_field }}) IN ('mercado libre', 'mercadolibre')
  THEN STRUCT('mercado libre' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'MX' AND LOWER({{ search_query_field }}) IN ('bodega aurrera', 'bodegaaurrera')
  THEN STRUCT('bodega aurrera' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'MX' AND LOWER({{ search_query_field }}) IN ('claro shop', 'claroshop')
  THEN STRUCT('claro shop' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'MX' AND LOWER({{ search_query_field }}) IN ('amazon', 'linio', 'liverpool', 'walmart', 'elektra', 'coppel', 'shein', 'shopee', 'aliexpress', 'ebay')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- Chile (CL)
  WHEN {{ country_field }} = 'CL' AND LOWER({{ search_query_field }}) IN ('mercado libre', 'mercadolibre')
  THEN STRUCT('mercado libre' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'CL' AND LOWER({{ search_query_field }}) IN ('falabella', 'ripley', 'paris', 'linio', 'yapo', 'shopee', 'aliexpress', 'shein', 'homecenter')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- Colombia (CO)
  WHEN {{ country_field }} = 'CO' AND LOWER({{ search_query_field }}) IN ('mercado libre', 'mercadolibre')
  THEN STRUCT('mercado libre' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'CO' AND LOWER({{ search_query_field }}) IN ('éxito', 'exito')
  THEN STRUCT('éxito' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'CO' AND LOWER({{ search_query_field }}) IN ('linio', 'falabella', 'amazon', 'olx', 'alkosto', 'homecenter', 'shein', 'shopee', 'aliexpress')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- PRIORITY 5: BROAD MATCHES - Nuestras marcas base
  
  -- Tiendanube base (MX, AR, CO, PE, CL)
  WHEN {{ country_field }} IN ('MX', 'AR', 'CO', 'PE', 'CL') AND (
    CONTAINS(LOWER({{ search_query_field }}), 'tiendanube') 
    OR CONTAINS(LOWER({{ search_query_field }}), 'tienda nube')
  ) THEN STRUCT('tiendanube' AS brand_name, 'broad' AS match_type)
  
  -- Nuvemshop base (solo BR)
  WHEN {{ country_field }} = 'BR' AND (
    CONTAINS(LOWER({{ search_query_field }}), 'nuvemshop') 
    OR CONTAINS(LOWER({{ search_query_field }}), 'nuvem shop')
  ) THEN STRUCT('nuvemshop' AS brand_name, 'broad' AS match_type)
  
  -- PRIORITY 6: BROAD MATCHES - Marketplaces por país
  {% for country, brands in [
    ('AR', ['mercado libre', 'mercadolibre', 'frávega', 'fravega', 'facebook marketplace', 'olx', 'amazon', 'aliexpress', 'ebay']),
    ('BR', ['mercado livre', 'mercadolivre', 'magalu', 'americanas', 'amazon', 'shopee', 'olx', 'submarino', 'netshoes', 'casas bahia', 'enjoei', 'shein', 'aliexpress']),
    ('MX', ['mercado libre', 'mercadolibre', 'amazon', 'linio', 'liverpool', 'walmart', 'elektra', 'coppel', 'bodega aurrera', 'claro shop', 'shein', 'shopee', 'aliexpress', 'ebay']),
    ('CL', ['falabella', 'mercado libre', 'mercadolibre', 'ripley', 'paris', 'linio', 'yapo', 'shopee', 'aliexpress', 'shein', 'homecenter']),
    ('CO', ['mercado libre', 'mercadolibre', 'linio', 'falabella', 'éxito', 'exito', 'amazon', 'olx', 'alkosto', 'homecenter', 'shein', 'shopee', 'aliexpress']),
    ('PE', [])
  ] %}
    {% for brand in brands %}
      WHEN {{ country_field }} = '{{ country }}' AND CONTAINS(LOWER({{ search_query_field }}), '{{ brand }}')
      THEN STRUCT('{{ brand }}' AS brand_name, 'broad' AS match_type)
    {% endfor %}
  {% endfor %}
  
  ELSE STRUCT(CAST(NULL AS STRING) AS brand_name, CAST(NULL AS STRING) AS match_type)
END
{% endmacro %}