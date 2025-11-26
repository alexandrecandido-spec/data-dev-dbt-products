{% macro get_kwp_category_mapping(search_query_field, country_field) %}
  CASE 
    -- ARGENTINA (AR)
    WHEN {{ country_field }} = 'AR' THEN
      CASE 
        -- Branded AR
        WHEN LOWER({{ search_query_field }}) IN (
          'bigcommerce', 'commerceup', 'empretienda', 'magento', 'mercado shops', 
          'mi negocio personal', 'prestashop', 'shopify', 'tienda negocio', 
          'tienda nube', 'tienda nube evolucion', 'tiendaneolo', 'tiendanube', 'tiendanube evolucion', 'tiendaup', 'vtex', 'wix', 'woo commerce'
        ) THEN 'Branded'
        
        -- Canales AR
        WHEN LOWER({{ search_query_field }}) IN (
          'como crear un facebook comercial', 'como crear una cuenta en instagram para vender',
          'como crear una pagina de ventas en instagram', 'como crear una pagina en instagram para vender',
          'como hacer un facebook comercial', 'como vender en instagram', 'como vender por instagram',
          'crear facebook comercial', 'crear pagina de facebook', 'crear tienda instagram',
          'tienda instagram', 'vender con facebook', 'vender por instagram', 'venta instagram'
        ) THEN 'Canales'
        
        -- Catálogo AR
        WHEN LOWER({{ search_query_field }}) IN (
          'armar catalogo online', 'crear catalogo de productos online'
        ) THEN 'Catálogo'
        
        -- Ecommerce AR
        WHEN LOWER({{ search_query_field }}) IN (
          'ecommerce', 'plataforma de ecommerce'
        ) THEN 'Ecommerce'
        
        -- Envíos AR
        WHEN LOWER({{ search_query_field }}) IN (
          'como hacer envios'
        ) THEN 'Envíos'
        
        -- Marketplace AR
        WHEN LOWER({{ search_query_field }}) IN (
          'aliexpress', 'amazon', 'ebay', 'facebook marketplace', 'frávega',
          'mercado libre', 'olx', 'shein', 'temu'
        ) THEN 'Marketplace'
        
        -- Página web AR
        WHEN LOWER({{ search_query_field }}) IN (
          'como crear pagina web de ventas', 'como crear una pagina para vender',
          'como crear una pagina para vender por internet', 'como hacer paginas web',
          'como hacer una pagina para vender', 'crear mi página web', 'crear pagina web',
          'hacer una pagina de ventas'
        ) THEN 'Página web'
        
        -- Tienda AR
        WHEN LOWER({{ search_query_field }}) IN (
          'como hacer una tienda online', 'crear tienda online', 'tienda en linea',
          'tienda online', 'tienda virtual'
        ) THEN 'Tienda'
        
        -- Vender AR
        WHEN LOWER({{ search_query_field }}) IN (
          'como vender por internet', 'vender online', 'vender por internet',
          'ventas online', 'ventas por internet'
        ) THEN 'Vender'
        
        ELSE 'Other'
      END
      
    -- BRASIL (BR)
    WHEN {{ country_field }} = 'BR' THEN
      CASE 
        -- Branded BR
        WHEN LOWER({{ search_query_field }}) IN (
          'bagy', 'iluria', 'loja integrada', 'magento', 'mercadoshops',
          'nuvem shop', 'nuvemshop', 'shopify', 'squarespace', 'tienda nube evolucion', 'tiendanube evolucion', 'tray',
          'vtex', 'wix', 'wix loja virtual', 'woo commerce'
        ) THEN 'Branded'
        
        -- Canais BR
        WHEN LOWER({{ search_query_field }}) IN (
          'como criar loja no instagram', 'como fazer loja no instagram', 'como vender na internet',
          'como vender no facebook', 'como vender no instagram', 'como vender pelo facebook',
          'como vender pelo instagram', 'como vender pelo whatsapp', 'criar loja no instagram',
          'instagram shopping', 'loja insta', 'loja no instagram', 'venda pelo instagram',
          'vendas no instagram', 'vendas pelo whatsapp', 'vender no instagram',
          'vender pelo instagram', 'vender pelo whatsapp'
        ) THEN 'Canais'
        
        -- Drop BR
        WHEN LOWER({{ search_query_field }}) IN (
          'dropshipping', 'dropshipping brasileiro', 'dropshipping nacional'
        ) THEN 'Drop'
        
        -- DTC BR
        WHEN LOWER({{ search_query_field }}) IN (
          'abrir loja virtual', 'catalogo online', 'como abrir loja virtual',
          'como abrir um e comerce', 'como abrir um ecommerce', 'como criar loja virtual',
          'como criar site de vendas', 'como criar um e commerce', 'como criar um site de vendas',
          'como fazer um site de vendas', 'como montar loja virtual', 'como montar um ecommerce',
          'como montar um site de vendas', 'criar loja online', 'criar loja virtual',
          'criar site de vendas', 'criar um site de vendas', 'loja online',
          'loja virtual', 'lojas virtuais', 'montar loja virtual', 'pagina de vendas',
          'plataforma de vendas'
        ) THEN 'DTC'
        
        -- E-commerce BR
        WHEN LOWER({{ search_query_field }}) IN (
          'comercio eletronico', 'plataforma e commerce', 'plataforma de ecommerce'
        ) THEN 'E-commerce'
        
        -- Envios BR
        WHEN LOWER({{ search_query_field }}) IN (
          'como enviar produtos pelo correio', 'quero trabalhar com entrega de produtos da internet'
        ) THEN 'Envios'
        
        -- Marketplace BR
        WHEN LOWER({{ search_query_field }}) IN (
          'amazon', 'americanas', 'enjoei', 'magalu', 'mercado livre',
          'olx', 'shein', 'shopee', 'submarino', 'temu'
        ) THEN 'Marketplace'
        
        -- Vendas BR
        WHEN LOWER({{ search_query_field }}) IN (
          'como fazer vendas online', 'como trabalhar com vendas online', 'como vender online',
          'como vender pela internet', 'como vender roupas pela internet', 'negocios on line',
          'plataformas de venda online', 'site de venda', 'site de venda online',
          'site de vendas', 'venda pela internet', 'vendas online', 'vender na internet',
          'vender on line', 'vender pela internet', 'vender produtos online', 'vender roupas online'
        ) THEN 'Vendas'
        
        ELSE 'Other'
      END
      
    -- CHILE (CL)
    WHEN {{ country_field }} = 'CL' THEN
      CASE 
        -- Branded CL
        WHEN LOWER({{ search_query_field }}) IN (
          'apanio', 'bsale', 'ecwid', 'jumpseller', 'kichink', 'mercado shops',
          'prestashop', 'shopify', 'tienda nube', 'tiendanube', 'vtex', 'wix', 'woocommerce'
        ) THEN 'Branded'
        
        -- Marketplace CL
        WHEN LOWER({{ search_query_field }}) IN (
          'falabella', 'linio', 'mercado libre', 'paris', 'ripley', 'yapo'
        ) THEN 'Marketplace'
        
        ELSE 'Other'
      END
      
    -- COLOMBIA (CO)
    WHEN {{ country_field }} = 'CO' THEN
      CASE 
        -- Branded CO
        WHEN LOWER({{ search_query_field }}) IN (
          'dropi', 'ecwid', 'empretienda', 'kichink', 'mercado shops', 'prestashop',
          'rocketfy', 'shopify', 'sumerlabs', 'tienda nube', 'tiendanube',
          'vtex', 'wix', 'woocommerce'
        ) THEN 'Branded'
        
        -- Marketplace CO
        WHEN LOWER({{ search_query_field }}) IN (
          'amazon', 'éxito', 'falabella', 'linio', 'mercado libre', 'olx'
        ) THEN 'Marketplace'
        
        ELSE 'Other'
      END
      
    -- MÉXICO (MX)
    WHEN {{ country_field }} = 'MX' THEN
      CASE 
        -- Branded MX
        WHEN LOWER({{ search_query_field }}) IN (
          'ecwid', 'kichink', 'magento', 'mercadoshops', 'prestashop', 'shopify',
          'squarespace', 't1paginas', 'tienda nube', 'tienda nube evolucion', 'tienda nube mexico',
          'tiendanube', 'tiendanube evolucion', 'tiendanube mexico', 'vtex', 'wix', 'woocommerce'
        ) THEN 'Branded'
        
        -- Canales MX
        WHEN LOWER({{ search_query_field }}) IN (
          'como crear un facebook comercial', 'como crear una cuenta en instagram para vender',
          'como crear una pagina de ventas en instagram', 'como crear una pagina en instagram para vender',
          'como hacer un facebook comercial', 'como vender en instagram', 'como vender por facebook',
          'como vender por instagram', 'como vender por tiktok', 'como vender por whatsapp',
          'crear facebook comercial', 'crear pagina de facebook', 'crear tienda facebook',
          'crear tienda instagram', 'tienda instagram', 'vender con facebook',
          'vender por instagram', 'venta instagram'
        ) THEN 'Canales'
        
        -- Catálogo MX
        WHEN LOWER({{ search_query_field }}) IN (
          'armar catalogo online', 'crear catalogo de productos online'
        ) THEN 'Catálogo'
        
        -- Drop MX
        WHEN LOWER({{ search_query_field }}) IN (
          'dropshipping'
        ) THEN 'Drop'
        
        -- Ecommerce MX
        WHEN LOWER({{ search_query_field }}) IN (
          'crear ecommerce', 'ecommerce', 'plataforma de ecommerce'
        ) THEN 'Ecommerce'
        
        -- Envíos MX
        WHEN LOWER({{ search_query_field }}) IN (
          'como hacer envios'
        ) THEN 'Envíos'
        
        -- Marketplace MX
        WHEN LOWER({{ search_query_field }}) IN (
          'amazon', 'coppel', 'elektra', 'linio', 'liverpool', 'mercado libre', 'walmart'
        ) THEN 'Marketplace'
        
        -- Página web MX
        WHEN LOWER({{ search_query_field }}) IN (
          'como crear pagina web de ventas', 'como crear una pagina para vender',
          'como crear una pagina para vender por internet', 'como hacer paginas web',
          'crear mi página web', 'crear pagina web', 'hacer una pagina de ventas'
        ) THEN 'Página web'
        
        -- Tienda MX
        WHEN LOWER({{ search_query_field }}) IN (
          'como hacer una tienda online', 'crear tienda en linea', 'crear tienda online',
          'tienda en linea', 'tienda online', 'tienda virtual'
        ) THEN 'Tienda'
        
        -- Vender MX
        WHEN LOWER({{ search_query_field }}) IN (
          'como vender en linea', 'como vender por internet', 'vender online',
          'vender por internet', 'ventas online', 'ventas por internet'
        ) THEN 'Vender'
        
        ELSE 'Other'
      END
      
    ELSE 'Other'
  END
{% endmacro %}
