with base_orders as(
select 
cart_id,
store_id,
event,
first_event_timestamp,
last_event_timestamp,
ROW_NUMBER() OVER (PARTITION BY cart_id ORDER BY first_event_timestamp) AS rn_first,
ROW_NUMBER() OVER (PARTITION BY cart_id ORDER BY last_event_timestamp desc) AS rn_last
from {{ ref('product__traffic__cart_checkout_by_event_type__event') }}
)
select
first_event.cart_id,
first_event.store_id,
first_event.event as first_event,
first_event.first_event_timestamp as first_event_timestamp,
last_event.event as last_event,
last_event.last_event_timestamp as last_event_timestamp
from base_orders first_event
left join base_orders last_event on first_event.cart_id = last_event.cart_id and last_event.rn_last = 1
where first_event.rn_first = 1