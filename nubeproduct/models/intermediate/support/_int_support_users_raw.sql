with
    stores as (
        select store_id
        from {{ ref("hubspot_active_stores") }}
    ),

    users as (
        select
            u.store_id,
            u.id as user_id,
            u.user_email as email
        from {{ source("int_moltres", "wp_users") }} u
        inner join stores s on u.store_id = s.store_id
        where u.user_email is not null
    ),

    store_settings as (
        select
            store_id,
            owner_phone_number,
            owner_phone_country,
            owner_phone_area
        from {{ source("int_moltres", "mwp_store_settings") }}
    ),

    partners as (
        select
            id as partner_id,
            email
        from {{ source("int_ecosystem", "mwp_partners") }}
        where email is not null
    )

select
    cast(u.user_id as int) as user_id,
    u.email,
    'User-' || cast(u.user_id as string) as name,
    u.store_id,
    {{ format_phone_e164('ss.owner_phone_country', 'ss.owner_phone_area', 'ss.owner_phone_number') }} as phone,
    case
        when p.partner_id is not null then true
        else false
    end as user_is_partner,
    p.partner_id,
    case
        when u.store_id is not null then true
        else false
    end as has_store
from users u
left join store_settings ss on u.store_id = ss.store_id
left join partners p on u.email = p.email
where u.email is not null
