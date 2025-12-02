churns as(
select
	s.deal_id,
	s.store_id,
	s.dealname,
	s.stage,
    s.country,
	coalesce(s.effective_churn_at,s.date_entered_effective_churn) as effective_churn_at,
	s.effective_churn_one_liner,
	s.effective_churn_root_cause,
	s.effective_churn_root_cause_2
from data_products_prd.data_midmarket.s__success__pipeline__snapshot as s
where
	s.stage = 'Effective churn'
),
dates as(SELECT
    dates as date_start, dateadd(day, 6, dates) as date_end 
FROM 
    -- Genera un array de fechas desde '2023-01-01' hasta el primer día del mes actual,
    -- con un intervalo de 1 mes.
    EXPLODE(
        sequence(
            DATE '2024-01-01',
            DATE_TRUNC('WEEK', CURRENT_DATE()), -- Asegura que la fecha final sea el inicio del mes actual
            INTERVAL '1' WEEK
        )
    ) AS t(dates)
)
select
d.date_start,
c.country,
'churns' as origen,
case when lower(c.effective_churn_root_cause) like '%pricing%' then 'Pricing'
when lower(c.effective_churn_root_cause) like '%issue%' then 'Issues'
when lower(c.effective_churn_root_cause) like '%problem%' then 'Problems'
when lower(c.effective_churn_root_cause) like '%other store%' then 'Other store no seller closed'
else 'Others' end as cause,
count(*) as merchants
from dates d
LEFT JOIN churns c on c.effective_churn_at between d.date_start and d.date_end
where date_start = cast('2024-01-01' as date)
group by 1,2,3,4
