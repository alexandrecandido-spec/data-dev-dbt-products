SELECT grupo AS group_name, namev2 AS group_desc,
       CASE 
           WHEN grupo IN ('test_broken','no-stores') THEN 0
           WHEN grupo IN ('zero-fee','freemium') THEN 1
           WHEN grupo IN ('lojinha','plan-a','plan-emprendedor') THEN 2
           WHEN grupo IN ('plan-b') THEN 3
           WHEN grupo IN ('plan-c') THEN 4
           WHEN grupo IN ('enterprise') THEN 5
       ELSE -1 END AS group_order_id,
       collect_list(plan) AS plan_id_nk
FROM   {{ ref('operations_grouping_plans') }}
GROUP BY 1,2,3