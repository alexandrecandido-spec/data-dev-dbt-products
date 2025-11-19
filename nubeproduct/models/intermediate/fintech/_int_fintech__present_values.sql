select
    CAST(hub_contract_id AS STRING) as hub_contract_id,
    round(sum(case when installment_due_date < current_date then installment_updated_amount else 0 end), 2) as present_overdue,
    round(sum(case when installment_due_date >= current_date then installment_updated_amount else 0 end), 2) as present_open,
    data_ref
from  {{ ref('fintech__lending__installment_present_value__snapshot_daily') }}
where year_month_day_code = CAST(date_format(current_date, 'yyyyMMdd') AS INT) 
group by 1,4