{% macro get_official_marketplace_flag(country_field, detected_brand_field) %}
CASE 
  WHEN {{ country_field }} = 'AR' AND {{ detected_brand_field }} IN (
    'facebook marketplace', 'mercado libre', 'amazon',
    'aliexpress', 'ebay', 'tiendanube', 'olx', 'shein', 'temu'
  ) THEN true
  
  WHEN {{ country_field }} = 'BR' AND {{ detected_brand_field }} IN (
    'amazon', 'americanas', 'magalu', 'mercado livre', 'olx',
    'shopee', 'submarino', 'casas bahia', 'netshoes', 'enjoei',
    'shein', 'aliexpress', 'nuvemshop', 'temu'
  ) THEN true
  
  WHEN {{ country_field }} = 'CL' AND {{ detected_brand_field }} IN (
    'falabella', 'linio', 'mercado libre', 'paris', 'ripley', 'yapo',
    'homecenter', 'shein', 'shopee', 'aliexpress', 'tiendanube'
  ) THEN true
  
  WHEN {{ country_field }} = 'CO' AND {{ detected_brand_field }} IN (
    'amazon', 'exito', 'falabella', 'linio', 'mercado libre', 'olx',
    'alkosto', 'homecenter', 'shein', 'shopee', 'aliexpress', 'tiendanube'
  ) THEN true
  
  WHEN {{ country_field }} = 'MX' AND {{ detected_brand_field }} IN (
    'amazon', 'coppel', 'elektra', 'linio', 'liverpool', 'mercado libre',
    'walmart', 'bodega aurrera', 'claro shop', 'shein', 'shopee',
    'aliexpress', 'ebay', 'tiendanube'
  ) THEN true
  
  -- Peru: Sin marcas oficiales por ahora
  WHEN {{ country_field }} = 'PE' THEN false
  
  ELSE false
END
{% endmacro %}
