SELECT 
    billing_cycle_id,
    external_store_id,
    SUM(CASE WHEN carrier_code = 'correios' THEN cost_charge_value ELSE 0 END) AS correios_cost_value,
    SUM(CASE WHEN carrier_code = 'jadlog' THEN cost_charge_value ELSE 0 END) AS jadlog_cost_value,
    SUM(CASE WHEN carrier_code = 'mandae' THEN cost_charge_value ELSE 0 END) AS mandae_cost_value,
    SUM(CASE WHEN carrier_code = 'loggi' THEN cost_charge_value ELSE 0 END) AS loggi_cost_value
FROM {{ ref('nuvem_envio__cycle_by_carrier') }}
GROUP BY 1, 2
