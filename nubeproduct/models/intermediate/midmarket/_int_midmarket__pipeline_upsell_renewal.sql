select
    d.deal_id,
    d.store_id,
    d.dealstage,
    d.dealname,
    d.hubspot_owner_id,
    d.responsavel_marketing,
    d.createdate,
    d.closedate,
    d.pipeline,
    d.client_upsell_motive,
    d.kickoff_date,
    d.gmv_potencial,
    d.potential_gross_profit_perc, 
    d.potential_gross_profit,
    d.subscription,
    d.cpt,
    d.success_priority,
    d.vertical,
    d.where_did_the_lead_came_from_ as acquisition_channel,
    d.date_entered_downgrade_ar,
    d.date_entered_downgrade_br,
    d.date_entered_downgrade_mx,
    d.closed_lost_reason__1__nuevmshop_,
    d.closed_lost_reason__2__nuevmshop_,
    d.closed_won_reason__1__nuevmshop_,
    d.closed_won_reason__2__nuevmshop_,
    d.closed_lost_notes_sales,
    d.notes_last_updated,
    d.company_name,
    d.date_entered_negotiation_upsell_success_ar,
    d.date_entered_negotiation_upsell_success_br,
    d.forecast_category,
    d.stage_before_closing_deal,
    d.cidade_territorio_sales,
    d.deal_tags
from {{ ref('midmarket__general__deals__link') }} as d
left join {{ ref('midmarket_hubspot_deleted_deals') }} as dd
    on cast(dd.deal_id as bigint) = d.deal_id
where 
    dd.deal_id is null
    and d.pipeline in ('Upsell Success | AR', 'Upsell Success | BR', 'Upsell Success | MX')