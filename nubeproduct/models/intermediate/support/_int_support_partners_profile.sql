-- Partners base model with email filtering for sync
select id as partner_id, email, name as partner_name, false as has_store, true as user_is_partner
from {{ source("int_ecosystem", "mwp_partners") }}
where email is not null
