-- _int__product__shipping__fallback_carrier_status_input

WITH carrier_status AS (
    
    SELECT
        o.order_id,
        sc.app_id as shipping_carrier_app_id,
        sc.id as sc_id,
        CASE
            WHEN sc.created_at < o.order_completed_at AND (sc.deleted_at > o.order_completed_at OR sc.deleted_at IS NULL)
                THEN TRUE
            ELSE FALSE
        END AS was_carrier_active_when_fallback
    
    FROM {{ ref('s__orders__orders_last_12_months__event') }} o

    JOIN {{ ref('s__shipping__fallback_status__ref') }} fs
    ON o.store_id = fs.store_id

    JOIN {{ source('int_moltres', 'mwp_shipping_carriers') }} sc
    ON o.store_id = sc.store_id

    WHERE 1=1
        AND o.order_completed_at IS NOT NULL
        AND o.payment_status = 'paid'
        AND o.status <> 'cancelled'
        AND o.storefront NOT IN ('form', 'pos')
        AND o.shipping_method = 'Fallback'

),

row_number AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, shipping_carrier_app_id
            ORDER BY CASE WHEN was_carrier_active_when_fallback = TRUE THEN 0 ELSE 1 END
        ) AS rn
    FROM carrier_status

)

SELECT
    
    o.store_id,
    fs.domain,
    fs.country,
    fs.plan_group,
    fs.segment,
    fs.state,
    fs.is_churned,
    fs.is_fallback_active,
    fs.is_freemium,
    o.order_id,
    sc.name AS shipping_carrier_name,
    sc.app_id as shipping_carrier_app_id,
    CASE
        WHEN sc.created_at < o.order_completed_at AND (sc.deleted_at > o.order_completed_at OR sc.deleted_at is null) THEN TRUE
        ELSE FALSE
    END AS was_carrier_active_when_fallback,
    o.shipping_method,
    CASE
        WHEN o.shipping_method = 'Fallback' THEN TRUE
        ELSE FALSE
    END AS is_fallback_order,
    DATE(o.order_completed_at) AS order_completed_at,
    CAST(date_format(o.order_completed_at, 'yyyyMMdd') AS INTEGER) AS year_month_day_code,

    GREATEST(
        COALESCE(o.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(fs.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
        COALESCE(sc.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
    ) AS sys_audit_updated_on


FROM {{ ref('s__orders__orders_last_12_months__event') }} o

JOIN {{ ref('s__shipping__fallback_status__ref') }} fs
    ON o.store_id = fs.store_id

JOIN {{ source('int_moltres', 'mwp_shipping_carriers') }} sc
    ON o.store_id = sc.store_id

JOIN row_number rn
    ON rn = 1
    AND rn.sc_id = sc.id
    AND rn.order_id = o.order_id
    AND rn.shipping_carrier_app_id = sc.app_id


WHERE 1=1
    AND o.order_completed_at IS NOT NULL
    AND o.payment_status = 'paid'
    AND o.status <> 'cancelled'
    AND o.storefront NOT IN ('form', 'pos')
    AND o.shipping_method = 'Fallback'