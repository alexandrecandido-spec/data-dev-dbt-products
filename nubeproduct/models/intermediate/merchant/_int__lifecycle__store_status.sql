WITH store_source AS (
  SELECT
    si.store_id
    , si.created_at
    , si.first_payment
    , si.churned_at
    , si.plan_id AS current_plan_id
    , si.state
    , si.disabled
    , si.custom_theme
    , si.sys_audit_updated_on
  FROM {{ ref('merchant__attributes__store_info__ref') }} si
), 
segment_info AS (
  SELECT
    l.store_id
    ,LOWER(cs.segment_name) as current_segment
    ,CASE WHEN LOWER(cs.segment_name) IN ('no-seller', 'struggling-seller') THEN 'no-seller' 
      WHEN LOWER(cs.segment_name) IN ('tiny-seller', 'small-seller', 'medium-seller', 'large-seller', 'top-seller') THEN 'seller'
      ELSE 'not informed' END AS is_seller
    ,LOWER(ms.segment_name) as max_segment
    ,l.sys_audit_updated_on
  FROM {{ ref('_int_dim_merchant_info__segment') }} l
  LEFT JOIN {{ ref('dimension__attributes__segment_type__ref') }} cs ON l.current_segment_id = cs.segment_id
  LEFT JOIN {{ ref('dimension__attributes__segment_type__ref') }} ms ON l.max_segment_id = ms.segment_id
),
blocked_store__info AS (
  SELECT
    bl.store_id
    , bl.blocked_at
    , bl.blocked_reason
    , bl.blocked_last_updated_at
  FROM {{ ref('merchant__attributes__store_tags__ref') }} bl
  WHERE bl.blocked_reason is not null
),
cancellations_info AS (
  SELECT 
  *
  FROM 
  (
    SELECT 
    c.store_id,
    c.reason AS cancellation_reason,
    trim(c.extra) AS cancellation_comment,
    c.created_at AS cancellation_comment_at,
    c.sys_audit_updated_on AS cancellation_updated_at,
    row_number() over (partition by store_id order by created_at desc) as row_rank
  FROM {{ source('int_moltres', 'mwp_store_cancellations') }} c) ca
  WHERE ca.row_rank = 1
),
midmarket_success_stores AS (
  SELECT 
  store_id
  FROM {{ ref('midmarket_success_stores') }}
  WHERE in_portfolio = true
),
active_finance AS (
  SELECT DISTINCT store_id
  FROM {{ source('int_finance', 'active_merchants') }}
  WHERE date = (
    SELECT MAX(date)
    FROM {{ source('int_finance', 'active_merchants') }}
  )
)


SELECT 
    ss.store_id
    , ss.created_at
    , ss.first_payment
    , ss.churned_at
    , fs.first_seller_at
    , CASE WHEN fs.first_seller_at IS NOT NULL AND ss.first_payment IS NOT NULL AND ss.first_payment <= fs.first_seller_at THEN TRUE ELSE FALSE END AS new_seller
    , ss.current_plan_id
    , COALESCE(pl.namev2, 'not informed') AS current_plan_name
    , COALESCE(pl.grupo, 'not informed') AS current_plan_type
    , COALESCE(pl.plan_context, 'not informed') AS current_plan_context
    , si.current_segment
    , si.is_seller
    , si.max_segment
    , CASE WHEN bl.store_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_store_blocked
    , bl.blocked_reason
    , bl.blocked_at
    , ss.state
    , ss.disabled
    , ss.custom_theme
    , CASE WHEN ss.first_payment IS NOT NULL THEN TRUE ELSE FALSE END AS new_payment
    , COALESCE(CASE WHEN ms.store_id IS NOT NULL THEN 'MM' ELSE 'SMB' END, 'SMB') AS business_unit
    , CASE WHEN ss.churned_at IS NOT NULL THEN ci.cancellation_reason ELSE NULL END AS cancellation_reason
    , CASE WHEN ss.churned_at IS NOT NULL THEN ci.cancellation_comment ELSE NULL END AS cancellation_comment
    , CASE WHEN ss.churned_at IS NOT NULL THEN ci.cancellation_comment_at ELSE NULL END AS cancellation_comment_at
    -- ACTIVE MERCHANTS: Agregado por pedido de Gi para el data product user_information
    , CASE 
        WHEN af.store_id IS NOT NULL AND COALESCE(pl.grupo, 'not informed') != 'freemium' THEN 'paying'
        WHEN af.store_id IS NOT NULL AND COALESCE(pl.grupo, 'not informed') = 'freemium' THEN 'free'
        ELSE 'not_active'
      END AS merchant_finance_status
    , GREATEST(ss.sys_audit_updated_on, si.sys_audit_updated_on, bl.blocked_last_updated_at, fs.sys_audit_updated_on) as change_timestamp
FROM store_source ss 
LEFT JOIN segment_info si ON ss.store_id = si.store_id
LEFT JOIN blocked_store__info bl ON ss.store_id = bl.store_id
LEFT JOIN cancellations_info ci ON ss.store_id = ci.store_id
LEFT JOIN midmarket_success_stores ms ON ss.store_id = ms.store_id
LEFT JOIN {{ ref('s__general__grouping_plans__ref') }} pl ON ss.current_plan_id = pl.plan
LEFT JOIN {{ ref('s__lifecycle__first_seller_date__ref') }} fs ON ss.store_id = fs.store_id
LEFT JOIN active_finance af ON ss.store_id = af.store_id