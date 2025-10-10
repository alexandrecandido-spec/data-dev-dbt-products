-- Consolidated auxiliary fields from various sources
with
    active as (select store_id from {{ ref("hubspot_active_stores") }}),

    layout as (
        select store_id, option_value as layout
        from {{ source("stg_moltres", "mwp_options") }}
        where option_name = 'twig_template'
    ),

    instagram as (
        select
            store_id,
            case when instagram is not null then true else false end as has_instagram
        from {{ source("stg_moltres", "mwp_store_settings") }}
    ),

    paid_until as (
        select store_id, unix_timestamp(paid_until) as paid_until_at
        from {{ ref("moltres__mwp_store_info") }}
        where paid_until is not null
    ),

    ftp as (select store_id, custom_theme from {{ ref("moltres__mwp_store_info") }}),

    has_partner as (
        select store_id, partner_id from {{ ref("moltres__mwp_store_info") }}
    ),

    user_confirmation as (
        select msi.store_id, wu.account_confirmed_at
        from {{ ref("moltres__mwp_store_info") }} msi
        left join {{ source("int_moltres", "wp_users") }} wu on msi.main_user_id = wu.id
    )

select
    a.store_id,
    cast(a.store_id as string) as external_id,
    l.layout,
    i.has_instagram,
    p.paid_until_at,
    case when f.custom_theme is not null then true else false end as ftp,
    case
        when hp.partner_id is not null then true else false
    end as has_associated_partner,
    case
        when uc.account_confirmed_at is not null then true else false
    end as confirmed_account
from active a
left join layout l on l.store_id = a.store_id
left join instagram i on i.store_id = a.store_id
left join paid_until p on p.store_id = a.store_id
left join ftp f on f.store_id = a.store_id
left join has_partner hp on hp.store_id = a.store_id
left join user_confirmation uc on uc.store_id = a.store_id
