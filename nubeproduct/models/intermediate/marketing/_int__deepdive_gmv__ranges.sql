with base as (
  select
    store_id,
    mes,
    country,
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
)

select
  b.store_id,
  b.mes,

  -- Bandas de GMV en moneda local (por mes puntual)
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

  -- Bandas de GMV en USD (por mes puntual)
  case
    when b.gmv_usd <= 80  then '≤80 USD'
    when b.gmv_usd <= 250 then '80–250 USD'
    when b.gmv_usd <= 700 then '250–700 USD'
    when b.gmv_usd <= 2600 then '700–2.6K USD'
    when b.gmv_usd >  2600 then '>2.6K USD'
    else 'Unknown'
  end as gmv_usd_monthly_range,

  -- Bandas “current” (sobre promedio 3M cerrado)
  case
    when a.avg_gmv_last_3_months is null then 'No longer selling'
    when b.country = 'AR' and a.avg_gmv_last_3_months <= 150000 then '≤150K ARS'
    when b.country = 'AR' and a.avg_gmv_last_3_months <= 450000 then '150K–450K ARS'
    when b.country = 'AR' and a.avg_gmv_last_3_months <= 1300000 then '450K–1.3M ARS'
    when b.country = 'AR' and a.avg_gmv_last_3_months <= 4700000 then '1.3M–4.7M ARS'
    when b.country = 'AR' then '>4.7M ARS'
    when b.country = 'BR' and a.avg_gmv_last_3_months <= 350 then '≤350 BRL'
    when b.country = 'BR' and a.avg_gmv_last_3_months <= 900 then '350–900 BRL'
    when b.country = 'BR' and a.avg_gmv_last_3_months <= 2500 then '900–2.5K BRL'
    when b.country = 'BR' and a.avg_gmv_last_3_months <= 9800 then '2.5K–9.8K BRL'
    when b.country = 'BR' then '>9.8K BRL'
    when b.country = 'CL' and a.avg_gmv_last_3_months <= 80000 then '≤80K CLP'
    when b.country = 'CL' and a.avg_gmv_last_3_months <= 160000 then '80K–160K CLP'
    when b.country = 'CL' and a.avg_gmv_last_3_months <= 450000 then '160K–450K CLP'
    when b.country = 'CL' and a.avg_gmv_last_3_months <= 3500000 then '450K–3.5M CLP'
    when b.country = 'CL' then '>3.5M CLP'
    when b.country = 'CO' and a.avg_gmv_last_3_months <= 250000 then '≤250K COP'
    when b.country = 'CO' and a.avg_gmv_last_3_months <= 660000 then '250K–660K COP'
    when b.country = 'CO' and a.avg_gmv_last_3_months <= 1600000 then '660K–1.6M COP'
    when b.country = 'CO' and a.avg_gmv_last_3_months <= 5100000 then '1.6M–5.1M COP'
    when b.country = 'CO' then '>5.1M COP'
    when b.country = 'MX' and a.avg_gmv_last_3_months <= 2000 then '≤2K MXN'
    when b.country = 'MX' and a.avg_gmv_last_3_months <= 4000 then '2K–4K MXN'
    when b.country = 'MX' and a.avg_gmv_last_3_months <= 10000 then '4K–10K MXN'
    when b.country = 'MX' and a.avg_gmv_last_3_months <= 28000 then '10K–28K MXN'
    when b.country = 'MX' then '>28K MXN'
    else 'Unknown'
  end as gmv_local_current_range,

  case
    when a.avg_gmv_usd_last_3_months is null then 'No longer selling'
    when a.avg_gmv_usd_last_3_months <= 80  then '≤80 USD'
    when a.avg_gmv_usd_last_3_months <= 250 then '80–250 USD'
    when a.avg_gmv_usd_last_3_months <= 700 then '250–700 USD'
    when a.avg_gmv_usd_last_3_months <= 2600 then '700–2.6K USD'
    when a.avg_gmv_usd_last_3_months >  2600 then '>2.6K USD'
    else 'Unknown'
  end as gmv_usd_current_range

from base b
left join avg3 a using (store_id)
