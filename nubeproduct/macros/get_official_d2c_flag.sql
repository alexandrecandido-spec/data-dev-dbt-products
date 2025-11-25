{% macro get_official_d2c_flag(country_field, detected_brand_field) %}
CASE 
  WHEN {{ country_field }} = 'AR' AND {{ detected_brand_field }} IN (
    'empretienda', 'mercadoshops', 'magento', 'tiendaneolo', 'tienda neolo',
    'mi negocio personal', 'shopify', 'tiendanube', 'tiedaup', 'tieda negocio',
    'bigcommerce', 'commerceup', 'woocommerce', 'prestashop', 'vtex'
  ) THEN true
  
  WHEN {{ country_field }} = 'BR' AND {{ detected_brand_field }} IN (
    'bagy', 'iluria', 'loja integrada', 'nuvemshop', 'shopify',
    'tray', 'vtex', 'woocommerce', 'mercadoshops', 'magento', 'squarespace'
  ) THEN true
  
  WHEN {{ country_field }} = 'CL' AND {{ detected_brand_field }} IN (
    'apanio', 'bsale', 'ecwid', 'jumpseller', 'kichink',
    'mercado shops', 'prestashop', 'shopify', 'tiendanube',
    'vtex', 'woocommerce'
  ) THEN true
  
  WHEN {{ country_field }} = 'CO' AND {{ detected_brand_field }} IN (
    'dropi', 'ecwid', 'empretienda', 'mercado shops',
    'prestashop', 'rocketfy', 'shopify', 'sumerlabs', 'tiendanube',
    'vtex', 'woocommerce'
  ) THEN true
  
  WHEN {{ country_field }} = 'MX' AND {{ detected_brand_field }} IN (
    'ecwid', 'kichink', 'mercadoshops', 'prestashop',
    'shopify', 'tiendanube', 'vtex', 'woocommerce'
  ) THEN true
  
  -- Peru: Sin marcas oficiales por ahora
  WHEN {{ country_field }} = 'PE' THEN false
  
  ELSE false
END
{% endmacro %}
