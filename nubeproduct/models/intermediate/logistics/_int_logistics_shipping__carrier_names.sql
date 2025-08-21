SELECT
      id
    , CONCAT('api_', CAST(id AS STRING)) AS shipping_method
    , name as carrier_name
    FROM 
        {{source('int_moltres', 'mwp_shipping_carriers') }}