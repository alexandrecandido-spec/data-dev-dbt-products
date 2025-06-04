SELECT
    pp.store_id,
    mv.model_id,
    pp.predicted_prob
FROM  {{source('int_data_predictors', 'marketing_new_payment_predictor')}} AS pp
LEFT JOIN {{source('int_data_predictors', 'marketing_model_version_aux')}} AS mv 
        ON pp.model_id = mv.model_id
        AND pp.created_at BETWEEN mv.became_production - INTERVAL '72 hours' 
        AND COALESCE(mv.left_production, '2999-12-31') - INTERVAL '72 hours' 
WHERE
    mv.became_production IS NOT NULL