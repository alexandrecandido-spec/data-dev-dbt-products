{{ config(materialized='view') }}

with base as (
  select store_id
  from {{ source('int_data_operations','company_metrics_merchant_info') }}
),
links as (
  select
    store_id,
    nullif(trim(instagram), '') as instagram,
    nullif(trim(facebook),  '') as facebook,
    nullif(trim(twitter),   '') as twitter,
    nullif(trim(tiktok),    '') as tiktok,
    nullif(trim(pinterest), '') as pinterest
  from {{ source('int_moltres','mwp_store_settings') }}
),
ig_stats as (
  select
    store_id, followers, following, posts, posts_likes,
    row_number() over (partition by store_id order by "date" desc) as rn
  from {{ source('int_moltres','instagram_store_info') }}
),
latest_ig as (
  select store_id,
         followers as instagram_followers, following, posts,
         case when posts_likes >= 0 then posts_likes else null end as posts_likes
  from ig_stats where rn = 1
)
select
  b.store_id,
  l.instagram,
  f.instagram_followers,
  f.following,
  f.posts,
  f.posts_likes,
  l.facebook,
  l.twitter,
  l.tiktok,
  l.pinterest
from base b
left join links     l on b.store_id = l.store_id
left join latest_ig f on b.store_id = f.store_id
