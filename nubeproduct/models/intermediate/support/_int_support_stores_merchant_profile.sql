-- Consolidated merchant profile fields from dim_merchant_info and related dims
with
    active as (select store_id from {{ ref("hubspot_active_stores") }}),

    base as (
        select
            merchant.store_id,
            merchant.domain,
            merchant.created_at,
            merchant.first_payment,
            merchant.country_id,
            merchant.group_id,
            merchant.current_segment_id
        from {{ ref("dim_merchant_info") }} merchant
    ),

    country as (select country_id, country_code from {{ ref("dim_location_country") }}),

    plan as (
        select group_id, coalesce(group_name, 'custom') as plan
        from {{ ref("dim_group_plan") }}
    ),

    segment as (select segment_id, segment_name from {{ ref("dim_segment_type") }})

select
    b.store_id,
    -- name from domain
    coalesce(nullif(trim(b.domain), ''), 'Organization-' || b.store_id) as name,
    -- age range from created_at
    case
        when datediff(current_date(), b.created_at) <= 7
        then '0-7d'
        when datediff(current_date(), b.created_at) <= 14
        then '8-14d'
        when datediff(current_date(), b.created_at) <= 30
        then '15-30d'
        when datediff(current_date(), b.created_at) <= 60
        then '31-60d'
        when datediff(current_date(), b.created_at) <= 90
        then '61-90d'
        when datediff(current_date(), b.created_at) <= 120
        then '91-120d'
        when datediff(current_date(), b.created_at) <= 180
        then '121-180d'
        when datediff(current_date(), b.created_at) <= 365
        then '181-365d'
        when datediff(current_date(), b.created_at) <= 730
        then '1-2a'
        else '+2a'
    end as age_range,
    -- payment range from first_payment
    case
        when b.first_payment is null
        then null
        when datediff(current_date(), b.first_payment) <= 7
        then '0-7d'
        when datediff(current_date(), b.first_payment) <= 14
        then '8-14d'
        when datediff(current_date(), b.first_payment) <= 30
        then '15-30d'
        when datediff(current_date(), b.first_payment) <= 60
        then '31-60d'
        when datediff(current_date(), b.first_payment) <= 90
        then '61-90d'
        when datediff(current_date(), b.first_payment) <= 120
        then '91-120d'
        when datediff(current_date(), b.first_payment) <= 180
        then '121-180d'
        when datediff(current_date(), b.first_payment) <= 365
        then '181-365d'
        when datediff(current_date(), b.first_payment) <= 730
        then '1-2a'
        else '+2a'
    end as range_since_first_payment,
    -- created_at formatted
    date_format(b.created_at, 'yyyy-MM-dd') as created_at_org,
    -- country code
    c.country_code as country,
    -- admin URL by country
    case
        when c.country_code = 'BR'
        then b.domain || '.lojavirtualnuvem.com.br/admin'
        else b.domain || '.mitiendanube.com/admin'
    end as url_admin,
    -- plan name
    p.plan as plan,
    -- segment name
    s.segment_name as status_by_orders
from active a
left join base b on b.store_id = a.store_id
left join country c on c.country_id = b.country_id
left join plan p on p.group_id = b.group_id
left join segment s on s.segment_id = b.current_segment_id
