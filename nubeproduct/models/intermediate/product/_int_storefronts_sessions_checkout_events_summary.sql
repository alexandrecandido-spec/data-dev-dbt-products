with base_orders as(
select 
cart_id,
max(store_id) as store_id,
min(base_date) as base_date
from {{ ref('product__traffic__cart_checkout_by_event_type__event') }}
where cart_id not in (1688764297, 1683120568, 1676687500)
group by 1
)
select
bo.cart_id,
bo.store_id,
bo.base_date,
checkout_start.first_event_timestamp as checkout_start_timestamp,
checkout_filled_email.first_event_timestamp as checkout_filled_email_timestamp,
checkout_filled_shipping_zipcode.first_event_timestamp as checkout_filled_shipping_zipcode_timestamp,
checkout_selected_shipping_method.first_event_timestamp as checkout_selected_shipping_method_timestamp,
checkout_filled_shipping_first_name.first_event_timestamp as checkout_filled_shipping_first_name_timestamp,
checkout_filled_shipping_last_name.first_event_timestamp as checkout_filled_shipping_last_name_timestamp,
checkout_filled_shipping_phone.first_event_timestamp as checkout_filled_shipping_phone_timestamp,
checkout_clicked_shipping_continue.first_event_timestamp as checkout_clicked_shipping_continue_timestamp,
checkout_clicked_shipping_continue_to_payment.first_event_timestamp as checkout_clicked_shipping_continue_to_payment_timestamp,
checkout_filled_billing_id_number.first_event_timestamp as checkout_filled_billing_id_number_timestamp,
checkout_checked_billing_same_address.first_event_timestamp as checkout_checked_billing_same_address_timestamp,
checkout_filled_billing_country.first_event_timestamp as checkout_filled_billing_country_timestamp,
checkout_filled_billing_business_name.first_event_timestamp as checkout_filled_billing_business_name_timestamp,
checkout_filled_billing_trade_name.first_event_timestamp as checkout_filled_billing_trade_name_timestamp,
checkout_filled_billing_state_registration.first_event_timestamp as checkout_filled_billing_state_registration_timestamp,
checkout_filled_billing_business_activity.first_event_timestamp as checkout_filled_billing_business_activity_timestamp,
checkout_selected_payment_method.first_event_timestamp as checkout_selected_payment_method_timestamp,
checkout_clicked_payment_complete_order.first_event_timestamp as checkout_clicked_payment_complete_order_timestamp,
checkout_order_placed.first_event_timestamp as checkout_order_placed_timestamp,
checkout_order_paid.first_event_timestamp as checkout_order_paid_timestamp
from base_orders bo 
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_start on bo.cart_id = checkout_start.cart_id and checkout_start.event = 'checkout_start' and bo.store_id = checkout_start.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_email on bo.cart_id = checkout_filled_email.cart_id and checkout_filled_email.event = 'checkout_filled_email' and bo.store_id = checkout_filled_email.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_shipping_zipcode on bo.cart_id = checkout_filled_shipping_zipcode.cart_id and checkout_filled_shipping_zipcode.event = 'checkout_filled_shipping_zipcode' and bo.store_id = checkout_filled_shipping_zipcode.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_selected_shipping_method on bo.cart_id = checkout_selected_shipping_method.cart_id and checkout_selected_shipping_method.event = 'checkout_selected_shipping_method' and bo.store_id = checkout_selected_shipping_method.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_shipping_first_name on bo.cart_id = checkout_filled_shipping_first_name.cart_id and checkout_filled_shipping_first_name.event = 'checkout_filled_shipping_first_name' and bo.store_id = checkout_filled_shipping_first_name.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_shipping_last_name on bo.cart_id = checkout_filled_shipping_last_name.cart_id and checkout_filled_shipping_last_name.event = 'checkout_filled_shipping_last_name' and bo.store_id = checkout_filled_shipping_last_name.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_shipping_phone on bo.cart_id = checkout_filled_shipping_phone.cart_id and checkout_filled_shipping_phone.event = 'checkout_filled_shipping_phone' and bo.store_id = checkout_filled_shipping_phone.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_clicked_shipping_continue on bo.cart_id = checkout_clicked_shipping_continue.cart_id and checkout_clicked_shipping_continue.event = 'checkout_clicked_shipping_continue' and bo.store_id = checkout_clicked_shipping_continue.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_clicked_shipping_continue_to_payment on bo.cart_id = checkout_clicked_shipping_continue_to_payment.cart_id and checkout_clicked_shipping_continue_to_payment.event = 'checkout_clicked_shipping_continue_to_payment' and bo.store_id = checkout_clicked_shipping_continue_to_payment.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_billing_id_number on bo.cart_id = checkout_filled_billing_id_number.cart_id and checkout_filled_billing_id_number.event = 'checkout_filled_billing_id_number' and bo.store_id = checkout_filled_billing_id_number.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_checked_billing_same_address on bo.cart_id = checkout_checked_billing_same_address.cart_id and checkout_checked_billing_same_address.event = 'checkout_checked_billing_same_address' and bo.store_id = checkout_checked_billing_same_address.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_billing_country on bo.cart_id = checkout_filled_billing_country.cart_id and checkout_filled_billing_country.event = 'checkout_filled_billing_country' and bo.store_id = checkout_filled_billing_country.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_billing_business_name on bo.cart_id = checkout_filled_billing_business_name.cart_id and checkout_filled_billing_business_name.event = 'checkout_filled_billing_business_name' and bo.store_id = checkout_filled_billing_business_name.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_billing_trade_name on bo.cart_id = checkout_filled_billing_trade_name.cart_id and checkout_filled_billing_trade_name.event = 'checkout_filled_billing_trade_name' and bo.store_id = checkout_filled_billing_trade_name.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_billing_state_registration on bo.cart_id = checkout_filled_billing_state_registration.cart_id and checkout_filled_billing_state_registration.event = 'checkout_filled_billing_state_registration' and bo.store_id = checkout_filled_billing_state_registration.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_filled_billing_business_activity on bo.cart_id = checkout_filled_billing_business_activity.cart_id and checkout_filled_billing_business_activity.event = 'checkout_filled_billing_business_activity' and bo.store_id = checkout_filled_billing_business_activity.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_selected_payment_method on bo.cart_id = checkout_selected_payment_method.cart_id and checkout_selected_payment_method.event = 'checkout_selected_payment_method' and bo.store_id = checkout_selected_payment_method.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_clicked_payment_complete_order on bo.cart_id = checkout_clicked_payment_complete_order.cart_id and checkout_clicked_payment_complete_order.event = 'checkout_clicked_payment_complete_order' and bo.store_id = checkout_clicked_payment_complete_order.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_order_placed on bo.cart_id = checkout_order_placed.cart_id and checkout_order_placed.event = 'checkout_order_placed' and bo.store_id = checkout_order_placed.store_id
left join {{ ref('product__traffic__cart_checkout_by_event_type__event') }} checkout_order_paid on bo.cart_id = checkout_order_paid.cart_id and checkout_order_paid.event = 'checkout_order_paid' and bo.store_id = checkout_order_paid.store_id