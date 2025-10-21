WITH rank_invoice AS (
    SELECT
        i.invoice_id AS invoice_id,
        i.cn_store_id AS cn_store_id,
        DATE(i.invoice_created_at) AS invoice_created_at,
        DATE(i.invoice_start_cycle_date) AS invoice_start_cycle_date,
        DATE(i.invoice_end_cycle_date) AS invoice_end_cycle_date,
        MIN(DATEDIFF(day, i.invoice_created_at, current_date)) OVER (PARTITION BY i.cn_store_id) AS days_since_last_invoice,
        i.invoice_count_conversation,
        i.invoice_cost_total,
        i.invoice_cost_total / coalesce(i.invoice_count_conversation, 0) AS cost_per_conversation,
        date_add(i.invoice_created_at,extra_grace_days) as grace_until,
        ist.state_id AS invoice_state_id,
        ist.invoice_state AS current_invoice_state,
        ist.paid_date,
        SUM(paid_invoices) OVER (PARTITION BY i.cn_store_id) paid_invoices,
        COUNT(i.invoice_id) OVER (PARTITION BY i.cn_store_id) total_invoices,
        MAX(ist.paid_date) OVER (PARTITION BY i.cn_store_id) last_paid_date,
        MAX(CASE when ist.state_id =1 THEN i.invoice_created_at END) OVER (PARTITION BY i.cn_store_id) last_paid_created_date,
        MIN(ist.paid_date) OVER (PARTITION BY i.cn_store_id) first_paid_date,
        MAX(date_add(i.invoice_created_at,extra_grace_days)) OVER (PARTITION BY i.cn_store_id) overall_grace_until,
        ROW_NUMBER() OVER (PARTITION BY i.cn_store_id ORDER BY i.invoice_created_at desc) AS rank_invoice,
        GREATEST(ist.sys_audit_updated_on, i.sys_audit_updated_on) AS sys_audit_updated_on
    FROM {{ref('nuvem_chat__invoice')}} i
    LEFT JOIN (
        SELECT
            invoice_id,
            invoice_state,
            state_id,
            sys_audit_updated_on,
            CASE when state_id = 1 THEN DATE(invoice_state_created_at) END AS paid_date,
            ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY invoice_state_created_at DESC) AS rank_state,
            MAX(CASE when state_id = 1 THEN 1 ELSE 0 END) OVER (PARTITION BY invoice_id) paid_invoices
            FROM {{ref('nuvem_chat__invoice_state')}}
    ) ist ON i.invoice_id = ist.invoice_id AND ist.rank_state = 1
    ),
invoices AS (
    SELECT
        ri.cn_store_id,
        ri.invoice_id AS last_invoice_id,
        ri.invoice_created_at,
        ri.invoice_start_cycle_date,
        ri.invoice_end_cycle_date,
        ri.days_since_last_invoice,
        ri.invoice_count_conversation AS last_invoice_count_conversation,
        ri.invoice_cost_total,
        ri.cost_per_conversation,
        ri.paid_invoices,
        ri.last_paid_date,
        ri.first_paid_date,
        ri.grace_until,
        ri.overall_grace_until,
        ri.current_invoice_state,
        ri.total_invoices,
        MAX(ri.sys_audit_updated_on) AS sys_audit_updated_on,
        COUNT(DISTINCT CASE WHEN DATE(c.conversation_created_at) > ri.invoice_end_cycle_date AND m.message_discr = 'bot' AND ch.channel_discr <> 'playground' THEN c.conversation_id END) AS ai_conversations_after_invoice
    FROM rank_invoice ri
    LEFT JOIN {{ref('nuvem_chat__conversation')}} c ON c.cn_store_id = ri.cn_store_id
    LEFT JOIN {{ref('nuvem_chat__channel')}} ch ON ch.channel_id = c.channel_id AND ch.channel_discr <> 'playground'
    LEFT JOIN {{ref('nuvem_chat__message')}} m ON m.conversation_id = c.conversation_id AND m.message_discr = 'bot'
    WHERE ri.rank_invoice = 1
    GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16),
unpaid_invoices_after_last_paid AS (
    SELECT
        ri.cn_store_id,
        COUNT(ri.invoice_id) AS unpaid_invoices_since_last_paid
    FROM rank_invoice ri
    WHERE ri.invoice_created_at > ri.last_paid_created_date AND ri.current_invoice_state = 'unpaid'
    GROUP BY ri.cn_store_id)
SELECT 
    s.store_id,
    s.cn_store_id,
    s.name AS cn_merchant_name,
    s.onboarding,
    DATE(s.installed_at) AS installed_at,
    DATE(bp.trial_start_date) AS trial_start_date,
    DATE(bp.trial_end_date) AS trial_end_date,
    DATE(bp.billing_cycle_start_date) AS cycle_start_date,
    DATE(bp.billing_cycle_end_date) AS cycle_end_date,
    p.last_invoice_id,
    p.invoice_created_at,
    p.invoice_start_cycle_date,
    p.invoice_end_cycle_date,
    p.days_since_last_invoice,
    p.last_invoice_count_conversation,
    p.paid_invoices,
    p.last_paid_date,
    p.first_paid_date,
    p.grace_until,
    p.overall_grace_until,
    p.current_invoice_state,
    p.total_invoices,
    ui.unpaid_invoices_since_last_paid,
    p.ai_conversations_after_invoice,
    count(distinct CASE WHEN (DATE(bp.trial_end_date)<DATE(c.conversation_created_at) OR DATE(bp.trial_end_date) is null ) AND m.message_discr = 'bot' AND ch.channel_discr <> 'playground' THEN c.conversation_id END) AS conversations_after_trial,
    count(distinct CASE WHEN DATE(bp.trial_end_date)>=DATE(c.conversation_created_at) AND m.message_discr = 'bot' AND ch.channel_discr <> 'playground' THEN c.conversation_id END) AS conversations_in_trial,
    count(distinct CASE WHEN m.message_discr = 'bot' AND ch.channel_discr <> 'playground' AND DATE(c.conversation_created_at) BETWEEN date_sub(current_date, 3) AND date_sub(current_date, 1) THEN c.conversation_id END) AS ai_conv_last_3d,
    MAX(CASE WHEN m.message_discr = 'bot' AND ch.channel_discr <> 'playground' THEN DATE(c.conversation_created_at) END) AS last_conversation_date,
    GREATEST(
        MAX(p.sys_audit_updated_on),
        MAX(c.sys_audit_updated_on),
        MAX(ch.sys_audit_updated_on),
        MAX(m.sys_audit_updated_on),
        MAX(bp.sys_audit_updated_on),
        MAX(s.sys_audit_updated_on)
    ) as max_sys_audit_updated_on
FROM {{ref('nuvem_chat__store')}} s
LEFT JOIN {{ref('nuvem_chat__billing_plan')}} bp ON bp.billing_plan_id = s.billing_plan_id
LEFT JOIN {{ref('nuvem_chat__conversation')}} c ON c.cn_store_id = s.cn_store_id
LEFT JOIN {{ref('nuvem_chat__channel')}} ch ON ch.channel_id = c.channel_id
LEFT JOIN {{ref('nuvem_chat__message')}} m ON m.conversation_id = c.conversation_id
LEFT JOIN invoices p on p.cn_store_id = s.cn_store_id
LEFT JOIN unpaid_invoices_after_last_paid ui ON ui.cn_store_id = s.cn_store_id
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24