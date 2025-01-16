WITH rec_orders AS (
    SELECT 
        CAST(id AS BIGINT) as order_id,
        (recurring_same_store_30_days = 1 OR recurring_30_days = 1) AS is_recurring_user_30d,
        (recurring_same_store_360_days = 1 OR recurring_360_days = 1) AS is_recurring_user_360d
    FROM {{ source('dp_orders', 'recurring_orders') }}
    WHERE completed_at >= DATE_ADD(DAY, -31, CURRENT_DATE)
),
wallet_users AS (
    SELECT 
        user_email,
        wallet_consented_at
        
    FROM {{ ref('stg_wallet__consented_user') }}
),
ab_tests AS (
    SELECT 
        order_id,
        test_name,
        variant,
        variant_name
    FROM {{ ref('stg_moltres__mwp_checkout_ab_tests') }}
),
gross_orders AS (
    SELECT 
        order_id,
        created_at,
        started_checkout_at,
        completed_contact_at,
        completed_at,
        total_in_usd,
        is_paid_order,
        storefront,
        device,
        store_id,
        country,
        vertical,
        store_current_segment,
        payment,
        contact_email
    FROM {{ ref('_int__gross_orders__orders_join_moltres') }}
),
 
wallet_events AS (
    SELECT 
        order_id,
        event,
        event_registration_at,
        has_shipping_option,
        contact_email
    FROM {{ ref('_int__wallet_events') }}
),
express_checkout AS (
    SELECT 
        order_id, 
        created_at
    FROM {{ ref('stg_wallet__started_checkout_express') }}
),
aggregation as (

SELECT 
      DISTINCT
      ab_tests.order_id
      -- test info
      , ab_tests.test_name
      , ab_tests.variant
      , ab_tests.variant_name
      -- timestamps
      , gross_orders.created_at  
      , gross_orders.started_checkout_at
      , COALESCE(wallet_events.event_registration_at, gross_orders.completed_contact_at, gross_orders.completed_at) AS checkout_filled_email_at
      , gross_orders.completed_contact_at
      , gross_orders.completed_at
      -- order info
      , gross_orders.total_in_usd
      , gross_orders.is_paid_order
      , gross_orders.storefront
      , wallet_events.has_shipping_option
      , gross_orders.device
      -- recurring order info
      , is_recurring_user_30d
      , is_recurring_user_360d
      -- store info
      , gross_orders.store_id
      , gross_orders.country
      , gross_orders.vertical
      , gross_orders.store_current_segment 
      , CASE WHEN gross_orders.payment LIKE '%nuvem%' OR gross_orders.payment LIKE '%nube%' THEN TRUE ELSE FALSE END AS nuvem_pago
      -- user info
      , COALESCE(gross_orders.contact_email, wallet_events.contact_email) AS contact_email
      -- wallet
      , wallet_events.event_registration_at AS wallet_customer_identification_at
      , CASE WHEN wallet_events.event = 'wallet_customer_login' then wallet_events.event_registration_at END AS wallet_customer_login_at
      , CASE WHEN express_checkout.created_at IS NOT NULL THEN TRUE ELSE FALSE END AS has_ec
  FROM
      ab_tests
  LEFT JOIN
      gross_orders 
      ON ab_tests.order_id = gross_orders.order_id
  LEFT JOIN 
      wallet_events
      ON ab_tests.order_id =  wallet_events.order_id
  LEFT JOIN 
      express_checkout
      ON gross_orders.order_id = express_checkout.order_id
  LEFT JOIN 
      rec_orders
      ON ab_tests.order_id = rec_orders.order_id
)
SELECT
      aggregation.*
      , wallet_users.wallet_consented_at
      -- time diff
      , DATE_DIFF(SECOND, created_at, started_checkout_at) AS time_created_started
      , DATE_DIFF(SECOND, started_checkout_at, checkout_filled_email_at) AS time_started_email
      , DATE_DIFF(SECOND, checkout_filled_email_at, completed_contact_at) AS time_email_next
      , DATE_DIFF(SECOND, completed_contact_at, completed_at) AS time_next_completed
      , DATE_DIFF(SECOND, created_at, completed_at) AS time_created_completed
      , DATE_DIFF(SECOND, started_checkout_at, completed_at) AS time_started_completed
      , DATE_DIFF(SECOND, wallet_customer_identification_at, wallet_customer_login_at) AS time_wid_wlogin
      , DATE_DIFF(SECOND, wallet_customer_login_at, completed_at) AS time_wlogin_completed
  FROM 
      aggregation
  LEFT JOIN 
      wallet_users
      ON aggregation.contact_email = wallet_users.user_email