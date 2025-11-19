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
)
    select
        CAST(hub_contract_id AS STRING) as hub_contract_id,
        min(due_at) as first_installment_at,
        min(case when paid_amount is null and due_at < current_date then date_add(due_at, 1) end) as overdue_start_date,
        datediff(current_date, min(case when paid_amount is null and due_at < current_date then due_at end)) as days_overdue,
        -- original
        round(sum(original_amount/100), 2) as original_total,
        round(sum(case when paid_amount is not null then original_amount/100 else 0 end), 2) as original_paid,
        round(sum(case when paid_amount is null and due_at < current_date then original_amount/100 else 0 end), 2) as original_overdue,
        round(sum(case when paid_amount is null and due_at >= current_date then original_amount/100 else 0 end), 2) as original_open,
        -- principal
        round(sum(principal_amount/100), 2) as principal_total,
        round(sum(case when paid_amount is not null then principal_amount/100 else 0 end), 2) as principal_paid,
        round(sum(case when paid_amount is null and due_at < current_date then principal_amount/100 else 0 end), 2) as principal_overdue,
        round(sum(case when paid_amount is null and due_at >= current_date then principal_amount/100 else 0 end), 2) as principal_open,
        -- interest
        round(sum(interest_amount/100), 2) as interest_total,
        round(sum(case when paid_amount is not null then interest_amount/100 else 0 end), 2) as interest_paid,
        round(sum(case when paid_amount is null and due_at < current_date then interest_amount/100 else 0 end), 2) as interest_overdue,
        round(sum(case when paid_amount is null and due_at >= current_date then interest_amount/100 else 0 end), 2) as interest_open
    from installments
    group by hub_contract_id
