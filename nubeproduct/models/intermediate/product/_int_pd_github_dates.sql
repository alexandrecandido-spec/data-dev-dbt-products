    SELECT distinct 
        date_trunc('month',first_day_of_month) as registered_month
    FROM {{ ref('dim_calendar') }} 
    where date(first_day_of_month) 
        between add_months(date_trunc('month', current_date()), -24)
        and date_Trunc('month',current_date)