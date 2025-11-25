
    SELECT
        order_id,
        currency,
        max(year_month_day_code) as year_month_day_code,
        MIN(happened_at) as paid_at,
        MAX(happened_at) as last_payment_at,
        sum(amount) as total_amount,
        sum(amount_usd) as total_amount_usd,
        max(sys_audit_updated_on) as sys_audit_updated_on
    FROM
        {{ ref('orders__order_money_flows__event') }}
    WHERE happened_at >= '2025-11-01' --Dívida técnica order_money_flow começa com a lógica de data de pagamento a partir de novembro de 2025. Time ferá rollout historico
    GROUP BY order_id,currency