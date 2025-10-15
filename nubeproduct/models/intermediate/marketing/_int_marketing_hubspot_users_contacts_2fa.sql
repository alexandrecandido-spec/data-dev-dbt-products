with factors as (
    select
        cast(user_id as bigint) as user_id,
        max(case when enabled = 1 then 1 else 0 end) as has_enabled_factor
    from {{ source('bronze_risk_new_admin', 'auth_authentication_factors') }}
    group by user_id
)

select
    f.user_id,
    case when f.has_enabled_factor = 1 then true else false end as has_2fa
from factors f

