-- Partner name logic using first_name and last_name from wp_users
with users_dedup as (
    select *, row_number() over (partition by user_email order by id) as rn
    from {{ source("int_moltres", "wp_users") }}
    where deleted = 0
)

select
    pp.partner_id,
    case
        -- If no user found OR user has demo stores, use partner name
        when
            u.id is null
            or exists (
                select 1
                from {{ ref("moltres__mwp_store_info") }} si
                where
                    si.store_id = u.store_id
                    and si.partner_id is not null
                    and si.state = 4
            )
        then coalesce(nullif(trim(pp.partner_name), ''), 'Partner-' || pp.partner_id)
        -- Otherwise use user's first_name + last_name, fallback to partner name
        else
            coalesce(
                nullif(
                    trim(
                        concat(
                            coalesce(nullif(trim(u.first_name), ''), ''),
                            case
                                when
                                    u.first_name is not null and u.last_name is not null
                                then ' '
                                else ''
                            end,
                            coalesce(nullif(trim(u.last_name), ''), '')
                        )
                    ),
                    ''
                ),
                nullif(trim(pp.partner_name), ''),
                'User-' || u.id
            )
    end as name
from {{ ref("_int_support_partners_profile") }} pp
left join users_dedup u on pp.email = u.user_email and u.rn = 1
