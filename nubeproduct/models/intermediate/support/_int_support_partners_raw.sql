with
    partner_tags as (
        select related_id as partner_id, string_agg(tag, ',') as partner_tags
        from {{ source("int_ecosystem", "tags") }}
        where type = 'partner' and tag in ('platinum', 'gold', 'silver')
        group by related_id
    )

select
    cast(mp.id as int) as partner_id,
    mp.email,
    mp.name,
    pt.partner_tags
from {{ source("int_ecosystem", "mwp_partners") }} as mp
left join partner_tags pt on mp.id = pt.partner_id
where mp.email is not null
