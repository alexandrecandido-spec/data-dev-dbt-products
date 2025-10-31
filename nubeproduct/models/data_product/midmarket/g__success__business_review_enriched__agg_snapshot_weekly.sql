-- Owner: Guille De Felice

{{
    config(
        materialized='table', 
        on_schema_change='fail',
        tags=['weekly-monday-1030am']
    )
}}

SELECT 
    wbr.*,
    si.domain as store_name,
    mi.vertical_name as vertical,
    CAST(si.churned_at AS DATE) as churned_at, 
    CAST(si.first_payment AS DATE) as first_payment,
    gp.lead_source,
    gp.deal_tags,
    gp.gmv_potencial,
    gp.data_go_live,
    gp.onboarding_type,
    gp.createdate,
    gmv.snapshot_orders_on_platform_weekly as orders,
    gmv.snapshot_gmv_local_currency_on_platform_weekly as gmv_local_currency,
    LAG(gmv.snapshot_gmv_local_currency_on_platform_weekly, 1) OVER (
        PARTITION BY wbr.store_id 
        ORDER BY wbr.date_from
    ) as previous_gmv_local_currency,
    gmv.snapshot_gmv_usd_on_platform_weekly as gmv_usd,
    t.gmv_local_currency_on_platform_90d as gmv_local_currency_90d,
    t.gmv_usd_on_platform_90d as gmv_usd_90d,
    t.gmv_tier,
    s.sessions,
    s.previous_sessions,
    i.calls,
    i.emails,
    i.meetings,
    i.tasks,
    i.whatsapp,
    nm.next_meeting,
    c.contract_end_date,
    'weekly' as periodicity

FROM 
    {{ ref('midmarket_weekly_business_review') }} wbr
    LEFT JOIN {{ ref('moltres__mwp_store_info') }} si
        on wbr.store_id = si.store_id
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__general_properties') }} gp
        on wbr.store_id = gp.store_id
    LEFT JOIN {{ ref('company_metrics_weekly_snapshot_gmv') }} gmv
        on wbr.store_id = gmv.store_id
        and wbr.date_from = gmv.date_from
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__tier') }} t
        on wbr.store_id = t.store_id
        and date_trunc('month', wbr.date_to) - interval 1 day = t.datemonth
    LEFT JOIN {{ ref('operations_grouping_sessions') }} s
        on wbr.store_id = s.store_id
        and wbr.date_from = s.date_from
        and s.periodicity = 'weekly'
    LEFT JOIN {{ ref('g__success__interactions__agg_snapshot_weekly_monthly') }} i
        on wbr.store_id = i.store_id
        and wbr.date_from = i.date_from
        and i.periodicity = 'weekly'
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__companies') }} c
        on wbr.store_id = c.store_id
    LEFT JOIN {{ ref('company_metrics_merchant_info') }} mi
        on wbr.store_id = mi.store_id
    LEFT JOIN {{ ref('_int_midmarket_wbr_mbr__next_meeting') }} nm
        on wbr.store_id = nm.store_id