{{
    config(
        unique_key=['date_id'],
        on_schema_change='fail',
        tags=['dimensions','manual']
    )
}}

WITH date_range AS (SELECT explode(sequence(to_date('2000-01-01'), to_date('2050-12-31'), interval 1 day)) AS full_date)
SELECT
 full_date AS date_id
,CAST(date_format(full_date, 'yyyyMMdd') AS INT) AS date_number
,year(full_date) AS year_id
,month(full_date) AS month_id
,date_format(full_date, 'MMMM') AS month_name
,date_format(full_date, 'EEEE') AS day_name
,quarter(full_date) AS quarter_id
,concat('Q', CAST(quarter(full_date) AS STRING)) AS quarter_name
,dayofyear(full_date) AS day_of_year
,day(full_date) AS day_of_month
,CASE WHEN dayofweek(full_date) = 1 THEN 7 ELSE dayofweek(full_date) - 1 END AS day_of_week_number
,CASE WHEN dayofweek(full_date) IN (1, 7) THEN true ELSE false END AS is_weekend
,trunc(full_date, 'MM') AS first_day_of_month
,date_sub(add_months(trunc(full_date, 'MM'), 1), 1) AS last_day_of_month
,trunc(full_date, 'week') AS first_day_of_week
,date_add(trunc(full_date, 'week'), 6) AS last_day_of_week
,weekofyear(full_date) AS week_of_year
FROM date_range
ORDER BY full_date