 SELECT 
     id
    , shipping_option_code
    , shipping_option
    , 'Correios' AS carrier_name
    , NULL AS shipping_partner
    , CASE
        WHEN shipping_option_code = 'ne-correios-sedex' THEN 'SEDEX'
        WHEN shipping_option_code = 'ne-correios-pac' THEN 'PAC'
        WHEN shipping_option_code = 'ne-correios-mini' THEN 'MINI'
        ELSE NULL
        END AS shipping_service
    , CASE
        WHEN shipping_option_code = 'ne-correios-sedex' THEN 'Correios - SEDEX'
        WHEN shipping_option_code = 'ne-correios-pac' THEN 'Correios - PAC'
        WHEN shipping_option_code = 'ne-correios-mini' THEN 'Correios - MINI'
        ELSE NULL
        END AS shipping_option_result
    FROM 
        {{ ref('_int_logistics_shipping__filtered_orders') }}
    WHERE 1=1
        AND shipping_option_code IN ('ne-correios-sedex','ne-correios-pac','ne-correios-mini')
        AND LOWER(shipping_option) NOT LIKE '%nuvem envio%'