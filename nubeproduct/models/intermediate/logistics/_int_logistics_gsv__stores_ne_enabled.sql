-- Identifies stores that have Nuvem Envio enabled.
-- Flags store_id with flg_ne_enabled = 1 when Nuvem Envio carrier is active in settings.

WITH
all_stores AS (
  SELECT
    c.store_id,
    c.name AS carrier_name
  FROM {{source('int_moltres', 'mwp_shipping_carriers') }} c
    INNER JOIN {{source('int_moltres', 'mwp_shipping_carriers_options') }} o
      ON o.carrier_id = c.id
  WHERE c.status = 1
      AND o.status = 1
)

-- Lojas que possuem Nuvem Envio habilitado

SELECT
    store_id,
    1 AS flg_ne_enabled
FROM all_stores
GROUP BY store_id
  HAVING 
    COUNT(DISTINCT CASE WHEN carrier_name = 'Nuvem Envio' THEN carrier_name END) > 0