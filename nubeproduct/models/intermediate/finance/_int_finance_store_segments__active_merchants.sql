SELECT
	LAST_DAY(TO_DATE(CAST(date_id AS STRING),
	'yyyyMMdd')) AS datemonth,
	store_id
FROM
	{{ source('intermediate_finance', 'active_merchants') }} act
WHERE
	date_id >= 20240101
	AND act.store_id_plan_country NOT IN (
    SELECT
		id
	FROM
		{{ source('intermediate', 'mwp_plans_countries') }}
	WHERE
		context LIKE '%freemium%'
		AND monthly = 0
)
GROUP BY
	LAST_DAY(TO_DATE(CAST(date_id AS STRING),
	'yyyyMMdd')),
	store_id