with downgrades as (
    select
        d.store_id,
        out_of_portfolio_root_cause as downgrade_root_cause_1,
        out_of_portfolio_root_cause_2 as downgrade_root_cause_2,
        out_of_portfolio_one_liner as downgrade_summary,
        competitor_identified,
        coalesce(date_entered_downgrade_br,
            coalesce(date_entered_downgrade_ar, date_entered_downgrade_mx)) as date_entered_downgrade,
        cidade_territorio_sales as city_state_downgrade,
        where_did_the_lead_came_from_ as channel,
        e_commerce,
        business_model_sales,
        type_of_onboarding as onboarding_type,
        responsavel_marketing
    from
        {{ source('dp_third_party', 'midmarket_hubspot_deals') }} d
        inner join {{ ref('midmarket_success_stores') }} s
            on d.deal_id = s.deal_id
)

select 
    store_id,
    downgrade_root_cause_1,
    downgrade_root_cause_2,
    downgrade_summary,
    competitor_identified,
    CAST(date_trunc('week', date_entered_downgrade) AS DATE) AS date_from,
    date_entered_downgrade::date as event_date,
    city_state_downgrade,
    channel,
    e_commerce,
    business_model_sales,
    onboarding_type,
    responsavel_marketing,
    'weekly' as periodicity
from 
    downgrades d 
where 
    date_entered_downgrade is not null