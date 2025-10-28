with
    organizations as (
        select
            cast(id as bigint) as organization_id,
            cast(external_id as bigint) as store_id
        from {{ source("stg_zendesk_support", "organizations") }}
    )

select organization_id, store_id
from organizations
