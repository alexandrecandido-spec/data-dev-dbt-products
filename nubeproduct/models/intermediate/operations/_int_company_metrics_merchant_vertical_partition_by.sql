SELECT store_id, vertifier FROM
(
SELECT store_id, vertifier, ROW_NUMBER() OVER(PARTITION BY store_id ORDER BY created_at DESC) AS rnk
FROM   {{ ref('antifraud_service__vertifier_store_inferences') }} 
) WHERE rnk = 1