-- Partner tags
with
    partner_tags as (
        select related_id as partner_id, string_agg(tag, ',') as partner_tags
        from {{ source("int_ecosystem", "tags") }}
        where type = 'partner' and tag in ('platinum', 'gold', 'silver')
        group by related_id
    )

select pp.partner_id, pt.partner_tags
from {{ ref("_int_support_partners_profile") }} as pp
left join partner_tags pt on pp.partner_id = pt.partner_id
