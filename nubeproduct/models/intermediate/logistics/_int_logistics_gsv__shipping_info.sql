-- Determines the selected shipping partner for each order.
-- Normalizes carrier names (Correios, Jadlog, etc.).
-- If Nuvem Envio is chosen, appends shipping partner details.
-- Covers shipping data from 2023 onwards.

SELECT
    order_id,
    shipping_partner,
    carrier_name,
    CASE
      WHEN carrier_name = 'Nuvem Envio' THEN CONCAT(carrier_name, ' - ', shipping_partner)
      WHEN carrier_name = 'Envío Nube' THEN CONCAT(carrier_name, ' - ', shipping_partner)
      WHEN carrier_name IN ('Correo Argentino Shipping', 'Correios', 'Envío Nube', 'Andreani Online',
                            'Melhor Envio', 'Mandaê', 'Frenet', 'Shipnow', 'OCA', 'Total Express',
                            'Manda Bem', 'Shippy', 'SuperFrete', 'Urbano Envios', 'Fast Mail', 'JadLog',
                            'Kangu', 'Envia.com Checkout Service', 'E-pick', 'BRCom', 'Pudo Argentina',
                            'Jipink') THEN carrier_name
      ELSE 'Outros'
      END AS selected_shipping_partner,
    shipping_option_result
  FROM {{ ref('logistics_shipping__orders_shipping_options') }}
  WHERE year_month_code >= 202301