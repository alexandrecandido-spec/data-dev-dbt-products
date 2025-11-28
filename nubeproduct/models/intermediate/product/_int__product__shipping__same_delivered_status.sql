-- _int__product__shipping__same_delivered_status

WITH fs as (
    SELECT
    DISTINCT order_id,
    MIN(app_id) as app_id,
    MIN(happened_at) as happened_at
    FROM {{ source('int_moltres', 'mwp_fulfillment_statuses') }}
    GROUP BY 1
)

SELECT
    po.id as order_id_,
    po.id as order_id,
    a.id as app_id_order,
    fs.app_id as app_id_delivered,
    CASE
        WHEN a.id IS NULL OR fs.app_id IS NULL THEN 'no info'
        WHEN a.id = fs.app_id then 'yes'
        ELSE 'no'
    END AS is_same_delivered_status

FROM {{ ref('company_metrics_paid_orders') }} po

JOIN {{ ref('s__lifecycle__store_status__ref') }} ss
    ON po.store_id = ss.store_id

JOIN {{ ref('s__attributes__store_core__ref') }} sc
    ON po.store_id = sc.store_id

LEFT JOIN {{ source('int_moltres', 'mwp_apps') }} a
    ON po.shipping = a.handle

LEFT JOIN fs
    ON po.id = fs.order_id

WHERE 1=1
    AND DATE(po.completed_at) > DATE(DATE_ADD(MONTH, -13, current_date))
    AND ss.state <> 4
