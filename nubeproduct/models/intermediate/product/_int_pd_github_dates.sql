    SELECT distinct 
        date_trunc('month',first_day_of_month) as registered_month
    FROM refined.data_dimensions.dim_calendar
    where date(first_day_of_month) 
        between date_add('month', -24, date_Trunc('month',current_date)) 
        and date_Trunc('month',current_date)