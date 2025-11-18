with new_warnings as (
    select
        store_id,
        warning_root_cause_1,
        warning_root_cause_2,
        warning_summary,
        warning_type,
        competitor_identified,
        CAST(date_trunc('week', date_entered_warning) AS DATE) AS date_from,
        date_entered_warning::date as event_date,
        ROW_NUMBER() OVER (PARTITION BY store_id, date_entered_warning ORDER BY date_to) AS rn
    from
        {{ ref('g__success__warnings__agg_snapshot_weekly') }} w
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
    new_warnings nw
where
    rn = 1
    and store_id > 0