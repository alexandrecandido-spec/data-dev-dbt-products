WITH months AS (
  	SELECT
    	sequence(to_date('2022-01-01'), current_date, interval 1 month) AS month_list
	)

SELECT
  last_day(tmp.datemonth) AS datemonth,
  act.store_id
FROM
  (
    SELECT
      explode(month_list) AS datemonth
    FROM
      months
  ) tmp
INNER JOIN
	{{ source('int_finance', 'active_merchants') }} act
	on
	last_day(tmp.datemonth) = act.date
	and act.date_id >= 20220101
WHERE
  	act.store_id_plan_country NOT IN (
		SELECT
		id
		FROM
		{{ source('int_moltres', 'mwp_plans_countries') }}
		WHERE
		context LIKE '%freemium%'
		AND monthly = 0
	)