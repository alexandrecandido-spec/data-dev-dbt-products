SELECT
    user_pseudo_id,
    first_visit_date
FROM "refined"."ga4"."first_visit"
GROUP BY user_pseudo_id

