with
    active_stores as (
        select store_id from {{ ref('hubspot_active_stores') }}
    ),

    main_users as (
        select msi.store_id, msi.main_user_id
        from {{ ref('moltres__mwp_store_info') }} as msi
        inner join active_stores a on a.store_id = msi.store_id
    ),

    users as (
        select
            wu.id as user_id,
            wu.user_email as email,
            wu.store_id,
            wu.deleted
        from {{ source('int_moltres', 'wp_users') }} as wu
        where wu.deleted <> 1
    )

select
    u.email,
    u.user_id,
    case when u.user_id = mu.main_user_id then true else false end as is_main_user,
    u.store_id
from users u
inner join main_users mu on mu.store_id = u.store_id

