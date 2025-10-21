WITH invoice_state as (
    SELECT
    invoice_id,
    invoice_state,
    state_id,
    sys_audit_updated_on,
    case when state_id = 1 then date(invoice_state_created_at) end as paid_date,
    max(case when state_id = 1 then 1 else 0 end) over (partition by invoice_id) paid_invoices,
    row_number() over (partition by invoice_id order by invoice_state_created_at desc) as rank_state
    FROM {{ref('nuvem_chat__invoice_state')}} 
)

SELECT 
    i.invoice_id,
    i.invoice_start_cycle_date,
    i.invoice_end_cycle_date,
    i.invoice_created_at,
    i.cn_store_id,
    i.invoice_count_conversation,
    i.invoice_cost_total,
    i.invoice_cost_total/coalesce(i.invoice_count_conversation, 0) as invoice_cost_per_conversation,
    is.invoice_state,
    GREATEST(
        MAX(is.sys_audit_updated_on),
        MAX(i.sys_audit_updated_on)
    ) as sys_audit_updated_on
    FROM {{ref('nuvem_chat__invoice')}} i 
    LEFT JOIN invoice_state is ON i.invoice_id = is.invoice_id AND is.rank_state = 1
    GROUP BY 1,2,3,4,5,6,7,8,9