WITH
fechas as (
    select
        registered_month
    from {{ ref('_int_pd_github_dates') }}
),
partners as (
    select
        partner_id
        ,partner_name
        ,email
        ,country_code
        ,phone_number
        ,website
        ,description
        ,partner_creation_date
        ,partner_type
    from {{ ref('product__ecosystem__tech_partner__countries') }}
),
partner_dates as (
    select
        f.registered_month
        ,p.*
    from fechas f
    cross join partners p
)
select
    p.registered_month
    ,p.partner_id
    ,p.partner_name
    ,p.email
    ,p.country_code
    ,p.phone_number
    ,p.website
    ,p.description
    ,p.partner_creation_date
    ,p.partner_type
    ,case when p.registered_month between date_trunc('month', p.partner_creation_date) and current_date then true else false end as is_partner_active
    ,case when p.registered_month = date_trunc('month', p.partner_creation_date) then true else false end as is_new_partner
from partner_dates p