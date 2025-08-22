-- Diagnosticar problema específico de GMV agosto

-- 1. ¿Qué snapshot_dates hay para agosto 2024?
SELECT 
    'date_spine_snapshots' as debug_type,
    snapshot_date,
    DATE_TRUNC('MONTH', snapshot_date) as snapshot_month,
    DAYOFWEEK(snapshot_date) as day_of_week,
    DATE_FORMAT(snapshot_date, 'EEEE') as day_name
FROM (
    SELECT DISTINCT first_day_of_week AS snapshot_date
    FROM testing_dimensions.dim_calendar
    WHERE date_id BETWEEN '2023-01-01' AND CURRENT_DATE()
    AND DATE_TRUNC('MONTH', first_day_of_week) = '2024-08-01'
) ds
ORDER BY snapshot_date;
