with
    stores as (select store_id from {{ ref("hubspot_active_stores") }}),

    users_with_active_stores as (
        select
            u.store_id,
            u.id as user_id,
            trim(lower(u.user_email)) as email,
            u.first_name,
            u.last_name,
            row_number() over (partition by u.user_email order by u.id desc, u.store_id) as rn
        from {{ source("int_moltres", "wp_users") }} u
        inner join stores s on u.store_id = s.store_id
        where u.deleted = 0 and u.user_email is not null and u.user_email <> ''
    ),

    users as (
        select store_id, user_id, email, first_name, last_name
        from users_with_active_stores
        where rn = 1
    ),

    store_settings as (
        select store_id, owner_phone_number, owner_phone_country, owner_phone_area
        from {{ source("int_moltres", "mwp_store_settings") }}
    ),

    partners as (
        select id as partner_id, email
        from {{ source("int_ecosystem", "mwp_partners") }}
        where email is not null
    ),

    organizations as (
        select
            cast(id as bigint) as organization_id,
            cast(external_id as bigint) as store_id
        from {{ source("int_zendesk_support_prod", "organizations") }}
    )

select
    cast(u.user_id as int) as user_id,
    u.email,
    {{ format_username("u.user_id", "u.first_name", "u.last_name") }} as name,
    {{format_phone_e164("ss.owner_phone_country", "ss.owner_phone_area", "ss.owner_phone_number")}} as phone,
    p.partner_id is not null as user_is_partner,
    p.partner_id,
    org.organization_id,
    u.store_id,
    true as has_store
from users u
left join store_settings ss on u.store_id = ss.store_id
left join partners p on u.email = p.email
left join organizations org on u.store_id = org.store_id
