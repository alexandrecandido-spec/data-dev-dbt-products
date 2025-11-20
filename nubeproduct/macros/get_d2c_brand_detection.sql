{% macro get_d2c_brand_detection(country_field, search_query_field) %}
CASE 
  -- PRIORITY 1: EXACT MATCHES - Nuestras marcas base
  
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
  
  -- PRIORITY 4: EXACT MATCHES - Competidores D2C con normalización
  
  -- Argentina (AR)
  WHEN {{ country_field }} = 'AR' AND LOWER({{ search_query_field }}) IN ('woo commerce', 'woocommerce')
  THEN STRUCT('woocommerce' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND LOWER({{ search_query_field }}) = 'mercado shops'
  THEN STRUCT('mercado shops' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND LOWER({{ search_query_field }}) IN ('tienda neolo', 'tiendaneolo')
  THEN STRUCT('tiendaneolo' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND LOWER({{ search_query_field }}) IN ('empretienda', 'magento', 'mi negocio personal', 'shopify', 'vtex', 'prestashop', 'bigcommerce', 'commerceup', 'tiedaup', 'tieda negocio', 'wix')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- Brasil (BR)
  WHEN {{ country_field }} = 'BR' AND LOWER({{ search_query_field }}) IN ('woo commerce', 'woocommerce')
  THEN STRUCT('woocommerce' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND LOWER({{ search_query_field }}) IN ('wix loja virtual', 'wix')
  THEN STRUCT('wix' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND LOWER({{ search_query_field }}) IN ('bagy', 'iluria', 'loja integrada', 'shopify', 'tray', 'vtex')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- México (MX)
  WHEN {{ country_field }} = 'MX' AND LOWER({{ search_query_field }}) IN ('woo commerce', 'woocommerce')
  THEN STRUCT('woocommerce' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'MX' AND LOWER({{ search_query_field }}) IN ('mercadoshops', 'mercado shops')
  THEN STRUCT('mercado shops' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'MX' AND LOWER({{ search_query_field }}) IN ('ecwid', 'kichink', 'magento', 'prestashop', 'shopify', 'squarespace', 't1paginas', 'vtex', 'wix')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- Chile (CL)
  WHEN {{ country_field }} = 'CL' AND LOWER({{ search_query_field }}) IN ('woo commerce', 'woocommerce')
  THEN STRUCT('woocommerce' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'CL' AND LOWER({{ search_query_field }}) = 'mercado shops'
  THEN STRUCT('mercado shops' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'CL' AND LOWER({{ search_query_field }}) IN ('apanio', 'bsale', 'ecwid', 'jumpseller', 'kichink', 'prestashop', 'shopify', 'vtex', 'wix')
  THEN STRUCT(LOWER({{ search_query_field }}) AS brand_name, 'exact' AS match_type)
  
  -- Colombia (CO)
  WHEN {{ country_field }} = 'CO' AND LOWER({{ search_query_field }}) IN ('woo commerce', 'woocommerce')
  THEN STRUCT('woocommerce' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'CO' AND LOWER({{ search_query_field }}) = 'mercado shops'
  THEN STRUCT('mercado shops' AS brand_name, 'exact' AS match_type)
  
  WHEN {{ country_field }} = 'CO' AND LOWER({{ search_query_field }}) IN ('dropi', 'ecwid', 'empretienda', 'kichink', 'prestashop', 'rocketfy', 'shopify', 'sumerlabs', 'vtex', 'wix')
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
  
  -- PRIORITY 6: BROAD MATCHES - Competidores D2C con normalización
  
  -- Argentina (AR)
  WHEN {{ country_field }} = 'AR' AND (CONTAINS(LOWER({{ search_query_field }}), 'woo commerce') OR CONTAINS(LOWER({{ search_query_field }}), 'woocommerce'))
  THEN STRUCT('woocommerce' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'mercado shops')
  THEN STRUCT('mercado shops' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND (CONTAINS(LOWER({{ search_query_field }}), 'tienda neolo') OR CONTAINS(LOWER({{ search_query_field }}), 'tiendaneolo'))
  THEN STRUCT('tiendaneolo' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'empretienda')
  THEN STRUCT('empretienda' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'magento')
  THEN STRUCT('magento' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'mi negocio personal')
  THEN STRUCT('mi negocio personal' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'shopify')
  THEN STRUCT('shopify' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'vtex')
  THEN STRUCT('vtex' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'prestashop')
  THEN STRUCT('prestashop' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'bigcommerce')
  THEN STRUCT('bigcommerce' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'commerceup')
  THEN STRUCT('commerceup' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'AR' AND CONTAINS(LOWER({{ search_query_field }}), 'wix')
  THEN STRUCT('wix' AS brand_name, 'broad' AS match_type)
  
  -- Brasil (BR)
  WHEN {{ country_field }} = 'BR' AND (CONTAINS(LOWER({{ search_query_field }}), 'woo commerce') OR CONTAINS(LOWER({{ search_query_field }}), 'woocommerce'))
  THEN STRUCT('woocommerce' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND (CONTAINS(LOWER({{ search_query_field }}), 'wix loja virtual') OR CONTAINS(LOWER({{ search_query_field }}), 'wix'))
  THEN STRUCT('wix' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND CONTAINS(LOWER({{ search_query_field }}), 'bagy')
  THEN STRUCT('bagy' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND CONTAINS(LOWER({{ search_query_field }}), 'iluria')
  THEN STRUCT('iluria' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND CONTAINS(LOWER({{ search_query_field }}), 'loja integrada')
  THEN STRUCT('loja integrada' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND CONTAINS(LOWER({{ search_query_field }}), 'shopify')
  THEN STRUCT('shopify' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND CONTAINS(LOWER({{ search_query_field }}), 'tray')
  THEN STRUCT('tray' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'BR' AND CONTAINS(LOWER({{ search_query_field }}), 'vtex')
  THEN STRUCT('vtex' AS brand_name, 'broad' AS match_type)
  
  -- México (MX) - casos específicos de normalización
  WHEN {{ country_field }} = 'MX' AND (CONTAINS(LOWER({{ search_query_field }}), 'woo commerce') OR CONTAINS(LOWER({{ search_query_field }}), 'woocommerce'))
  THEN STRUCT('woocommerce' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'MX' AND (CONTAINS(LOWER({{ search_query_field }}), 'mercadoshops') OR CONTAINS(LOWER({{ search_query_field }}), 'mercado shops'))
  THEN STRUCT('mercado shops' AS brand_name, 'broad' AS match_type)
  
  -- Chile (CL) - casos específicos de normalización  
  WHEN {{ country_field }} = 'CL' AND (CONTAINS(LOWER({{ search_query_field }}), 'woo commerce') OR CONTAINS(LOWER({{ search_query_field }}), 'woocommerce'))
  THEN STRUCT('woocommerce' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'CL' AND CONTAINS(LOWER({{ search_query_field }}), 'mercado shops')
  THEN STRUCT('mercado shops' AS brand_name, 'broad' AS match_type)
  
  -- Colombia (CO) - casos específicos de normalización
  WHEN {{ country_field }} = 'CO' AND (CONTAINS(LOWER({{ search_query_field }}), 'woo commerce') OR CONTAINS(LOWER({{ search_query_field }}), 'woocommerce'))
  THEN STRUCT('woocommerce' AS brand_name, 'broad' AS match_type)
  
  WHEN {{ country_field }} = 'CO' AND CONTAINS(LOWER({{ search_query_field }}), 'mercado shops')
  THEN STRUCT('mercado shops' AS brand_name, 'broad' AS match_type)
  
  ELSE STRUCT(CAST(NULL AS STRING) AS brand_name, CAST(NULL AS STRING) AS match_type)
END
{% endmacro %}