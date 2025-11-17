with base as (
  select
    store_id,
    mes,
    coalesce(country, 'Unknown') as country,
    gmv,
    gmv_usd
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }}
),

avg3 as (
  select
    store_id,
    avg_gmv_last_3_months,
    avg_gmv_usd_last_3_months
  from {{ ref('_int__deepdive_gmv__avg3m_constants') }}
),

bounds as (
  -- último mes CERRADO (fin del mes anterior al actual)
  select last_day(add_months(current_date, -1)) as last_closed_mes
),

last_closed as (
  -- GMV del último mes cerrado por tienda (si no vendió, no habrá fila)
  select
    m.store_id,
    m.gmv     as last_closed_gmv,
    m.gmv_usd as last_closed_gmv_usd
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }} m
  cross join bounds b
  where m.mes = b.last_closed_mes
)

select
  b.store_id,
  b.mes,

  -- Bandas de GMV en moneda local (por mes puntual = b.mes)
  case
    when b.country = 'AR' and b.gmv <= 150000 then '≤150K ARS'
    when b.country = 'AR' and b.gmv <= 450000 then '150K–450K ARS'
    when b.country = 'AR' and b.gmv <= 1300000 then '450K–1.3M ARS'
    when b.country = 'AR' and b.gmv <= 4700000 then '1.3M–4.7M ARS'
    when b.country = 'AR' then '>4.7M ARS'
    when b.country = 'BR' and b.gmv <= 350 then '≤350 BRL'
    when b.country = 'BR' and b.gmv <= 900 then '350–900 BRL'
    when b.country = 'BR' and b.gmv <= 2500 then '900–2.5K BRL'
    when b.country = 'BR' and b.gmv <= 9800 then '2.5K–9.8K BRL'
    when b.country = 'BR' then '>9.8K BRL'
    when b.country = 'CL' and b.gmv <= 80000 then '≤80K CLP'
    when b.country = 'CL' and b.gmv <= 160000 then '80K–160K CLP'
    when b.country = 'CL' and b.gmv <= 450000 then '160K–450K CLP'
    when b.country = 'CL' and b.gmv <= 3500000 then '450K–3.5M CLP'
    when b.country = 'CL' then '>3.5M CLP'
    when b.country = 'CO' and b.gmv <= 250000 then '≤250K COP'
    when b.country = 'CO' and b.gmv <= 660000 then '250K–660K COP'
    when b.country = 'CO' and b.gmv <= 1600000 then '660K–1.6M COP'
    when b.country = 'CO' and b.gmv <= 5100000 then '1.6M–5.1M COP'
    when b.country = 'CO' then '>5.1M COP'
    when b.country = 'MX' and b.gmv <= 2000 then '≤2K MXN'
    when b.country = 'MX' and b.gmv <= 4000 then '2K–4K MXN'
    when b.country = 'MX' and b.gmv <= 10000 then '4K–10K MXN'
    when b.country = 'MX' and b.gmv <= 28000 then '10K–28K MXN'
    when b.country = 'MX' then '>28K MXN'
    else 'Unknown'
  end as gmv_local_monthly_range,

  -- Bandas de GMV en USD (por mes puntual = b.mes)
  case
    when b.gmv_usd <= 80  then '≤80 USD'
    when b.gmv_usd <= 250 then '80–250 USD'
    when b.gmv_usd <= 700 then '250–700 USD'
    when b.gmv_usd <= 2600 then '700–2.6K USD'
    when b.gmv_usd >  2600 then '>2.6K USD'
    else 'Unknown'
  end as gmv_usd_monthly_range,

  /* =========
     Current ranges = último mes CERRADO (si no vendió => "No longer selling")
     ========= */
  case
    when lc.last_closed_gmv is null then 'No longer selling'
    when b.country = 'AR' and lc.last_closed_gmv <= 150000 then '≤150K ARS'
    when b.country = 'AR' and lc.last_closed_gmv <= 450000 then '150K–450K ARS'
    when b.country = 'AR' and lc.last_closed_gmv <= 1300000 then '450K–1.3M ARS'
    when b.country = 'AR' and lc.last_closed_gmv <= 4700000 then '1.3M–4.7M ARS'
    when b.country = 'AR' then '>4.7M ARS'
    when b.country = 'BR' and lc.last_closed_gmv <= 350 then '≤350 BRL'
    when b.country = 'BR' and lc.last_closed_gmv <= 900 then '350–900 BRL'
    when b.country = 'BR' and lc.last_closed_gmv <= 2500 then '900–2.5K BRL'
    when b.country = 'BR' and lc.last_closed_gmv <= 9800 then '2.5K–9.8K BRL'
    when b.country = 'BR' then '>9.8K BRL'
    when b.country = 'CL' and lc.last_closed_gmv <= 80000 then '≤80K CLP'
    when b.country = 'CL' and lc.last_closed_gmv <= 160000 then '80K–160K CLP'
    when b.country = 'CL' and lc.last_closed_gmv <= 450000 then '160K–450K CLP'
    when b.country = 'CL' and lc.last_closed_gmv <= 3500000 then '450K–3.5M CLP'
    when b.country = 'CL' then '>3.5M CLP'
    when b.country = 'CO' and lc.last_closed_gmv <= 250000 then '≤250K COP'
    when b.country = 'CO' and lc.last_closed_gmv <= 660000 then '250K–660K COP'
    when b.country = 'CO' and lc.last_closed_gmv <= 1600000 then '660K–1.6M COP'
    when b.country = 'CO' and lc.last_closed_gmv <= 5100000 then '1.6M–5.1M COP'
    when b.country = 'CO' then '>5.1M COP'
    when b.country = 'MX' and lc.last_closed_gmv <= 2000 then '≤2K MXN'
    when b.country = 'MX' and lc.last_closed_gmv <= 4000 then '2K–4K MXN'
    when b.country = 'MX' and lc.last_closed_gmv <= 10000 then '4K–10K MXN'
    when b.country = 'MX' and lc.last_closed_gmv <= 28000 then '10K–28K MXN'
    when b.country = 'MX' then '>28K MXN'
    else 'Unknown'
  end as gmv_local_current_range,

  case
    when lc.last_closed_gmv_usd is null then 'No longer selling'
    when lc.last_closed_gmv_usd <= 80  then '≤80 USD'
    when lc.last_closed_gmv_usd <= 250 then '80–250 USD'
    when lc.last_closed_gmv_usd <= 700 then '250–700 USD'
    when lc.last_closed_gmv_usd <= 2600 then '700–2.6K USD'
    when lc.last_closed_gmv_usd >  2600 then '>2.6K USD'
    else 'Unknown'
  end as gmv_usd_current_range,

  /* =========
     NUEVOS: Ranges por promedio 3M (nunca “No longer selling”)
     ========= */
  case
    when b.country = 'AR' and coalesce(a.avg_gmv_last_3_months, 0) <= 150000 then '≤150K ARS'
    when b.country = 'AR' and coalesce(a.avg_gmv_last_3_months, 0) <= 450000 then '150K–450K ARS'
    when b.country = 'AR' and coalesce(a.avg_gmv_last_3_months, 0) <= 1300000 then '450K–1.3M ARS'
    when b.country = 'AR' and coalesce(a.avg_gmv_last_3_months, 0) <= 4700000 then '1.3M–4.7M ARS'
    when b.country = 'AR' then '>4.7M ARS'
    when b.country = 'BR' and coalesce(a.avg_gmv_last_3_months, 0) <= 350 then '≤350 BRL'
    when b.country = 'BR' and coalesce(a.avg_gmv_last_3_months, 0) <= 900 then '350–900 BRL'
    when b.country = 'BR' and coalesce(a.avg_gmv_last_3_months, 0) <= 2500 then '900–2.5K BRL'
    when b.country = 'BR' and coalesce(a.avg_gmv_last_3_months, 0) <= 9800 then '2.5K–9.8K BRL'
    when b.country = 'BR' then '>9.8K BRL'
    when b.country = 'CL' and coalesce(a.avg_gmv_last_3_months, 0) <= 80000 then '≤80K CLP'
    when b.country = 'CL' and coalesce(a.avg_gmv_last_3_months, 0) <= 160000 then '80K–160K CLP'
    when b.country = 'CL' and coalesce(a.avg_gmv_last_3_months, 0) <= 450000 then '160K–450K CLP'
    when b.country = 'CL' and coalesce(a.avg_gmv_last_3_months, 0) <= 3500000 then '450K–3.5M CLP'
    when b.country = 'CL' then '>3.5M CLP'
    when b.country = 'CO' and coalesce(a.avg_gmv_last_3_months, 0) <= 250000 then '≤250K COP'
    when b.country = 'CO' and coalesce(a.avg_gmv_last_3_months, 0) <= 660000 then '250K–660K COP'
    when b.country = 'CO' and coalesce(a.avg_gmv_last_3_months, 0) <= 1600000 then '660K–1.6M COP'
    when b.country = 'CO' and coalesce(a.avg_gmv_last_3_months, 0) <= 5100000 then '1.6M–5.1M COP'
    when b.country = 'CO' then '>5.1M COP'
    when b.country = 'MX' and coalesce(a.avg_gmv_last_3_months, 0) <= 2000 then '≤2K MXN'
    when b.country = 'MX' and coalesce(a.avg_gmv_last_3_months, 0) <= 4000 then '2K–4K MXN'
    when b.country = 'MX' and coalesce(a.avg_gmv_last_3_months, 0) <= 10000 then '4K–10K MXN'
    when b.country = 'MX' and coalesce(a.avg_gmv_last_3_months, 0) <= 28000 then '10K–28K MXN'
    when b.country = 'MX' then '>28K MXN'
    else 'Unknown'
  end as gmv_local_avg3m_range,

  case
    when coalesce(a.avg_gmv_usd_last_3_months, 0) <= 80  then '≤80 USD'
    when coalesce(a.avg_gmv_usd_last_3_months, 0) <= 250 then '80–250 USD'
    when coalesce(a.avg_gmv_usd_last_3_months, 0) <= 700 then '250–700 USD'
    when coalesce(a.avg_gmv_usd_last_3_months, 0) <= 2600 then '700–2.6K USD'
    when coalesce(a.avg_gmv_usd_last_3_months, 0) >  2600 then '>2.6K USD'
    else 'Unknown'
  end as gmv_usd_avg3m_range

from base b
left join avg3 a using (store_id)
left join last_closed lc using (store_id)
