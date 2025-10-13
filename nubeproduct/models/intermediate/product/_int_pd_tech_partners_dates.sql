WITH
fechas as (
    select
        registered_month
    {{ ref('_int_pd_github_dates') }}
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
    from {{ ref('ecosystem_tech_partners') }}
),
partner_dates as (
    select
        f.registered_month
        ,p.*
    from fechas f
    cross join partners p
)
select
    pd.registered_month
    ,p.partner_id
    ,p.partner_name
    ,p.email
    ,p.country_code
    ,p.phone_number
    ,p.website
    ,p.description
    ,p.partner_creation_date
    ,p.partner_type
from partner_dates pd