-- Este modelo cria uma base unificada e enriquecida para todos os pagamentos do sistema legado.
-- Ele parte dos pagamentos e enriquece com dados de contrato e faturas (incluindo impostos da AR).

-- Versão final e corrigida do modelo de pagamentos legados.
-- Utiliza o campo 'paid_at' real e inclui a data de churn.

WITH
-- Etapa 1: Unificar todas as faturas legadas e seus detalhes
all_legacy_invoices AS (
    SELECT *
    FROM {{ ref('_int_finance__legacy_invoices_subscription') }}
),

-- Etapa 2: Unificar todos os pagamentos legados
all_legacy_payments AS (
    SELECT *
    FROM {{ ref('_int_finance__legacy_payments_subscription') }}
),

-- Etapa 3: Construir a base final, partindo dos pagamentos e enriquecendo com as faturas e churn
-- IMPORTANTE: A ordem das colunas deve ser EXATAMENTE igual à do new_payments_data para o UNION funcionar
final_legacy_payments_br_ar AS (
    SELECT
        p.plan,
        -- Chaves (ordem deve corresponder ao new_payments_data)
        p.payment_id AS charge_id,
        i.invoice_number AS invoice_number,
        p.payment_id AS external_reference,
        coalesce(p.store_id, i.store_id) AS store_id,
        coalesce(p.country_code, i.country_code) AS store_country,
        'plan-cost' AS concept_code,

        -- Datas
        IFNULL(p.from_date, i.issued_at) as from_date,
        IFNULL(p.to_date, i.issued_at) as to_date,
        IFNULL(p.paid_at, i.issued_at) AS paid_at,
        i.issued_at,
        p.churned_at, 

        -- Valores
        coalesce(p.amount_value, i.net_amount) AS amount_value,
        i.net_amount AS invoice_amount_value,
        i.document_type,

        'online' AS on_off_subs,
        NULLIF(DATEDIFF(DAY, p.from_date, p.to_date) + 1, 0) AS plan_days

    FROM all_legacy_invoices i 
    LEFT JOIN
        all_legacy_payments p ON p.payment_id = i.legacy_payment_id
    WHERE i.country_code in ('BR', 'AR')
),

final_legacy_payments_mx AS (
    SELECT
        p.plan,
        -- Chaves (ordem deve corresponder ao new_payments_data)
        p.payment_id AS charge_id,
        i.invoice_number AS invoice_number,
        p.payment_id AS external_reference,
        coalesce(p.store_id, i.store_id) AS store_id,
        coalesce(p.country_code, i.country_code) AS store_country,
        'plan-cost' AS concept_code,

        -- Datas
        IFNULL(p.from_date, p.paid_at) as from_date,
        IFNULL(p.to_date, p.paid_at) as to_date,
        p.paid_at,
        i.issued_at,
        p.churned_at, 

        -- Valores
        coalesce(p.amount_value/1.16,0) AS amount_value,
        coalesce(i.net_amount, 0) AS invoice_amount_value,
        i.document_type,

        'online' AS on_off_subs,
        NULLIF(DATEDIFF(DAY, p.from_date, p.to_date) + 1, 0) AS plan_days

    FROM all_legacy_payments p
    LEFT JOIN
        all_legacy_invoices i ON p.payment_id = i.legacy_payment_id
    WHERE p.country_code = 'MX'
),

final_legacy_payments_co_cl AS (
    SELECT
        p.plan,
        -- Chaves (ordem deve corresponder ao new_payments_data)
        p.payment_id AS charge_id,
        null AS invoice_number,
        p.payment_id AS external_reference,
        p.store_id,
        p.country_code AS store_country,
        'plan-cost' AS concept_code,

        -- Datas
        IFNULL(p.from_date, p.paid_at) as from_date,
        IFNULL(p.to_date, p.paid_at) as to_date,
        p.paid_at,
        p.paid_at AS issued_at,
        p.churned_at, 

        -- Valores
        coalesce(p.amount_value/1.19, 0) AS amount_value,
        0 AS invoice_amount_value,
        'invoice' as document_type,

        'online' AS on_off_subs,
        NULLIF(DATEDIFF(DAY, IFNULL(p.from_date, p.paid_at), IFNULL(p.to_date, p.paid_at)) + 1, 0) AS plan_days

    FROM all_legacy_payments p
    WHERE p.country_code in ('CO', 'CL')
)

SELECT * FROM final_legacy_payments_br_ar
UNION ALL
SELECT * FROM final_legacy_payments_mx
UNION ALL
SELECT * FROM final_legacy_payments_co_cl