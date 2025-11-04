select
cbk._id cbk_id,
cbk.storeId store_id,
cbk.orderId order_id,
cbk.events cbk_events,
cbk.amount cbk_amount,
cbk.chargeback cbk_chargeback,
cbk.customer cbk_customer,
cbk.chargeback.deadline cbk_deadline,
cbk.createdAt_date cbk_created_at,
cbk.paidAt order_paid_at,
cbk.chargeback.reason cbk_reason,
cbk.chargeback.status cbk_status,
cbk.failureReason cbk_failure_reason,
cbk.orderNumber cbk_order_number,
cbk.origin cbk_origin,
cbk.paymentMethod cbk_payment_method,
cbk.remainingAmountToRefund cbk_remaining_amount_to_refund,
cbk.status order_cbk_status,
cbk.year_month_code cbk_year_month_code,
msi.country,
msi.domain,
msi.state,
msi.current_segment,
gp.grupo plan_name,
GREATEST(
    cbk.sys_audit_updated_on,
    msi.sys_audit_updated_on,
    gp.sys_audit_updated_on
) as max_sys_audit_updated_on
from {{ref('nuvem_pago__chargebacks__chargebacks__event')}} cbk
left join {{ref('moltres__mwp_store_info')}} msi on cbk.storeid = msi.store_id
left join {{ref('operations_grouping_plans')}} gp on gp.plan = msi.plan
where chargeback.deadline is not null 


