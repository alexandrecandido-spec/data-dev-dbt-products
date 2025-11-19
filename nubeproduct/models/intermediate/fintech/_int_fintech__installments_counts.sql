with installments as (
    select
        hub_contract_id,
        due_at,
        paid_amount,
        original_amount,
        principal_amount,
        interest_amount
    from {{ source('int_nuvem_credito','installments') }}
    where status <> 'closed'
),
installment_status as (
    select distinct
        hub_contract_id,
        date_format(due_at, 'yyyyMM') as year_month,
        case when paid_amount is not null then 1 else 0 end as paid,
        case when paid_amount is null and due_at < current_date then 1 else 0 end as overdue,
        case when paid_amount is null and due_at >= current_date then 1 else 0 end as open
    from installments
),
installment_status_grouped as (
    select
        hub_contract_id,
        year_month,
        case
            when max(open) = 1 and max(paid) = 1 then 0
            when max(overdue) = 1 and max(paid) = 1 then 0
            else max(paid)
        end as paid,
        max(overdue) as overdue,
        max(open) as open
    from installment_status
    group by hub_contract_id, year_month
)
    select
        CAST(hub_contract_id AS STRING) as hub_contract_id,
        sum(paid) as installments_paid,
        sum(overdue) as installments_overdue,
        sum(open) as installments_open
    from installment_status_grouped
    group by hub_contract_id