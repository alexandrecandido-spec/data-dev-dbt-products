SELECT
    user_pseudo_id,
    min(first_visit_date) as first_visit_date
FROM {{ source('int_ga4', 'first_visit') }}
GROUP BY user_pseudo_id

