-- Este modelo intermediário aplica a lógica de negócio para identificar
-- as transações de CPT legadas para a Argentina (AR), excluindo lojas de teste e fraudes.
-- Ele não é materializado, servindo como uma view lógica para o data product final.

WITH mwp_payment_transaction_fees AS (
    SELECT * FROM {{ source('int_moltres', 'mwp_payment_transaction_fees') }}
),

mwp_payments AS (
    SELECT * FROM {{ source('int_moltres', 'mwp_payments') }}
),

mwp_store_info AS (
    SELECT * FROM {{ source('int_moltres', 'mwp_store_info') }}
),

fraud_stores AS (
    -- CTE para identificar lojas bloqueadas por fraude ou erros.
    -- Esta lógica é isolada para manter a query principal mais limpa.
    SELECT
        related_id AS store_id
    FROM
        {{ source('int_moltres', 'mwp_tags') }}
    WHERE
        tag IN ('sre-block-store-404', 'sre-block-store-429')
    GROUP BY 1
)

SELECT
    ptf.id,
    p.id AS payment_id,
    si.id AS store_id,
    si.country AS store_country,
    ptf.promo AS concept_code,
    ptf.start_date,
    ptf.end_date,
    -- Aplica a regra de negócio para remover impostos apenas para AR
    CASE
        WHEN si.country = 'AR' THEN ptf.price / 1.21
        ELSE ptf.price
    END AS amount_value
FROM
    mwp_payment_transaction_fees AS ptf
LEFT JOIN
    mwp_payments AS p ON ptf.payment_id = p.id
LEFT JOIN
    mwp_store_info AS si ON p.store_id = si.id
LEFT JOIN
    fraud_stores AS fraude ON si.id = fraude.store_id
WHERE
    fraude.store_id IS NULL       -- Exclui lojas identificadas como fraude (anti-join)
    AND si.country in ('AR','BR')       
    AND si.state <> 4             -- Exclui lojas de teste
    AND p.state = 2               -- Filtra por estado de pagamento (ex: 'paid')
    AND ptf.start_date < '2023-06-01' -- Garante dados somente até o final de Maio/2023