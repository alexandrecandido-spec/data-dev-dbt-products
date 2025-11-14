with outgoing_warnings as (
    SELECT
        w.store_id,
        warning_root_cause_1,
        warning_root_cause_2,
        warning_summary,
        warning_type,
        competitor_identified,
        CAST(DATE_TRUNC('week', w.date_exited_warning) AS DATE) AS date_from,
        w.date_exited_warning::date as event_date,
        ROW_NUMBER() OVER (PARTITION BY w.store_id, w.date_exited_warning ORDER BY date_to DESC) AS rn
    FROM
        {{ ref('_int_midmarket_warnings__weekly_warnings') }} w
    where 
        w.date_exited_warning is not null
)

select
    store_id,
    warning_root_cause_1,
    warning_root_cause_2,
    warning_summary,
    warning_type,
    competitor_identified,
    date_from,
    event_date,
    'weekly' as periodicity
from
    outgoing_warnings ow
where
    rn = 1
    and store_id > 0