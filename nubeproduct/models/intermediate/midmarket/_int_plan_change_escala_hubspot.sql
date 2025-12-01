WITH deals_raw AS (
    SELECT DISTINCT
        d.store_id AS store_id_hubspot,
        d.deal_id,
        d.pipeline,
        d.deal_owner,
        d.stage,
        d.type_of_onboarding,
        d.gmv_potencial,
        CAST(d.closedate AS DATE) AS deal_close_date
    FROM {{ ref('s__sales__pipeline__snapshot') }} d
    WHERE
        d.stage = 'Won'
        AND d.produto_nuvemshop = 'Plano Escala + Outros planos - (SMB) '
),

deals AS (
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY store_id_hubspot 
                    ORDER BY deal_close_date DESC
               ) AS rn
        FROM deals_raw
    ) sub
    WHERE rn = 1
),

plans AS (
    SELECT 
        mpc.plan,
        mpc.grupo
    FROM {{ ref('operations_grouping_plans') }} mpc
),

payments_after_deal AS (
    SELECT
        pay_header.store_id,
        CAST(MIN(pay_header.paid_at) AS DATE) AS first_payment_escala_after_close_date,
        deal.deal_close_date
    FROM {{ source('int_moltres', 'mwp_payment_stores') }} pay_event
    INNER JOIN plans pg
        ON pg.plan = pay_event.plan_id
    LEFT JOIN {{ source('int_moltres', 'mwp_payments') }} pay_header
        ON pay_event.payment_id = pay_header.id
    INNER JOIN deals deal
        ON deal.store_id_hubspot = pay_header.store_id
    WHERE pay_header.paid_at > deal.deal_close_date
    GROUP BY pay_header.store_id, deal.deal_close_date
)

SELECT 
    d.store_id_hubspot,
    d.deal_id,
    d.pipeline,
    d.deal_owner,
    d.stage,
    d.type_of_onboarding,
    d.gmv_potencial,
    d.deal_close_date,
    p.first_payment_escala_after_close_date
FROM deals d
LEFT JOIN payments_after_deal p
    ON d.store_id_hubspot = p.store_id
    AND d.deal_close_date = p.deal_close_date