-- Owner: Maria Blanco

with deals_all as (
  select
    cast(deal_id as bigint) as deal_id,
    pipeline,
    dealstage,
    store_id,
    createdate,
    closedate,
    associated_deal_ids
  from {{ ref('midmarket__general__deals__link') }}
),

assoc_expanded as (
  select
    d.deal_id as from_deal_id,
    trim(x)   as assoc_str
  from deals_all d
  lateral view outer explode(
    case
      when d.associated_deal_ids is null then array(cast(null as string))
      else split(d.associated_deal_ids, ';')
    end
  ) t as x
),

edges_directed as (
  select distinct
    from_deal_id,
    try_cast(assoc_str as bigint) as to_deal_id
  from assoc_expanded
  where try_cast(assoc_str as bigint) is not null
    and try_cast(assoc_str as bigint) <> from_deal_id
),

enriched as (
  select
    e.from_deal_id, df.pipeline as from_pipeline, df.dealstage as from_dealstage, df.createdate as from_createdate,
    e.to_deal_id,   dt.pipeline as to_pipeline,   dt.dealstage as to_dealstage,   dt.createdate as to_createdate
  from edges_directed e
  left join deals_all df on df.deal_id = e.from_deal_id
  left join deals_all dt on dt.deal_id = e.to_deal_id
),

scored as (
  select
    *,
    case
      when from_createdate is not null and to_createdate is not null and from_createdate > to_createdate then 1
      when from_createdate is not null and to_createdate is not null and from_createdate = to_createdate and from_deal_id > to_deal_id then 1
      else 0
    end as should_flip
  from enriched
)

select distinct
  case when should_flip = 1 then to_deal_id    else from_deal_id    end as from_deal_id,
  case when should_flip = 1 then to_pipeline   else from_pipeline   end as from_pipeline,
  case when should_flip = 1 then to_dealstage  else from_dealstage  end as from_dealstage,
  case when should_flip = 1 then to_createdate else from_createdate end as from_createdate,

  case when should_flip = 1 then from_deal_id    else to_deal_id    end as to_deal_id,
  case when should_flip = 1 then from_pipeline   else to_pipeline   end as to_pipeline,
  case when should_flip = 1 then from_dealstage  else to_dealstage  end as to_dealstage,
  case when should_flip = 1 then from_createdate else to_createdate end as to_createdate
from scored