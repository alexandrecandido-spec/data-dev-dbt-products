with base_orders as(
select 
cart_id,
store_id,
min(base_date) as base_date
from {{ ref('product__checkout_events_event') }}
group by 1,2
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
left join {{ ref('product__checkout_events_event') }} checkout_start on bo.cart_id = checkout_start.cart_id and checkout_start.event = 'checkout_start'
left join {{ ref('product__checkout_events_event') }} checkout_filled_email on bo.cart_id = checkout_filled_email.cart_id and checkout_filled_email.event = 'checkout_filled_email'
left join {{ ref('product__checkout_events_event') }} checkout_filled_shipping_zipcode on bo.cart_id = checkout_filled_shipping_zipcode.cart_id and checkout_filled_shipping_zipcode.event = 'checkout_filled_shipping_zipcode'
left join {{ ref('product__checkout_events_event') }} checkout_selected_shipping_method on bo.cart_id = checkout_selected_shipping_method.cart_id and checkout_selected_shipping_method.event = 'checkout_selected_shipping_method'
left join {{ ref('product__checkout_events_event') }} checkout_filled_shipping_first_name on bo.cart_id = checkout_filled_shipping_first_name.cart_id and checkout_filled_shipping_first_name.event = 'checkout_filled_shipping_first_name'
left join {{ ref('product__checkout_events_event') }} checkout_filled_shipping_last_name on bo.cart_id = checkout_filled_shipping_last_name.cart_id and checkout_filled_shipping_last_name.event = 'checkout_filled_shipping_last_name'
left join {{ ref('product__checkout_events_event') }} checkout_filled_shipping_phone on bo.cart_id = checkout_filled_shipping_phone.cart_id and checkout_filled_shipping_phone.event = 'checkout_filled_shipping_phone'
left join {{ ref('product__checkout_events_event') }} checkout_clicked_shipping_continue on bo.cart_id = checkout_clicked_shipping_continue.cart_id and checkout_clicked_shipping_continue.event = 'checkout_clicked_shipping_continue'
left join {{ ref('product__checkout_events_event') }} checkout_clicked_shipping_continue_to_payment on bo.cart_id = checkout_clicked_shipping_continue_to_payment.cart_id and checkout_clicked_shipping_continue_to_payment.event = 'checkout_clicked_shipping_continue_to_payment'
left join {{ ref('product__checkout_events_event') }} checkout_filled_billing_id_number on bo.cart_id = checkout_filled_billing_id_number.cart_id and checkout_filled_billing_id_number.event = 'checkout_filled_billing_id_number'
left join {{ ref('product__checkout_events_event') }} checkout_checked_billing_same_address on bo.cart_id = checkout_checked_billing_same_address.cart_id and checkout_checked_billing_same_address.event = 'checkout_checked_billing_same_address'
left join {{ ref('product__checkout_events_event') }} checkout_filled_billing_country on bo.cart_id = checkout_filled_billing_country.cart_id and checkout_filled_billing_country.event = 'checkout_filled_billing_country'
left join {{ ref('product__checkout_events_event') }} checkout_filled_billing_business_name on bo.cart_id = checkout_filled_billing_business_name.cart_id and checkout_filled_billing_business_name.event = 'checkout_filled_billing_business_name'
left join {{ ref('product__checkout_events_event') }} checkout_filled_billing_trade_name on bo.cart_id = checkout_filled_billing_trade_name.cart_id and checkout_filled_billing_trade_name.event = 'checkout_filled_billing_trade_name'
left join {{ ref('product__checkout_events_event') }} checkout_filled_billing_state_registration on bo.cart_id = checkout_filled_billing_state_registration.cart_id and checkout_filled_billing_state_registration.event = 'checkout_filled_billing_state_registration'
left join {{ ref('product__checkout_events_event') }} checkout_filled_billing_business_activity on bo.cart_id = checkout_filled_billing_business_activity.cart_id and checkout_filled_billing_business_activity.event = 'checkout_filled_billing_business_activity'
left join {{ ref('product__checkout_events_event') }} checkout_selected_payment_method on bo.cart_id = checkout_selected_payment_method.cart_id and checkout_selected_payment_method.event = 'checkout_selected_payment_method'
left join {{ ref('product__checkout_events_event') }} checkout_clicked_payment_complete_order on bo.cart_id = checkout_clicked_payment_complete_order.cart_id and checkout_clicked_payment_complete_order.event = 'checkout_clicked_payment_complete_order'
left join {{ ref('product__checkout_events_event') }} checkout_order_placed on bo.cart_id = checkout_order_placed.cart_id and checkout_order_placed.event = 'checkout_order_placed'
left join {{ ref('product__checkout_events_event') }} checkout_order_paid on bo.cart_id = checkout_order_paid.cart_id and checkout_order_paid.event = 'checkout_order_paid'