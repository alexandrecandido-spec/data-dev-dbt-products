with base as (
  select store_id
  from {{ ref('company_metrics_merchant_info') }}
),

-- CONTACTS
store_settings as (
  select
    store_id,
    phone,
    whatsapp_phone_number as whatsapp,
    case
      when owner_phone_number like '+%' then owner_phone_number
      -- si no viene con prefijo, armamos: +<country><area><number>, evitando NULLs
      when owner_phone_country is not null
        or owner_phone_area    is not null
        or owner_phone_number  is not null
      then concat(
        '+',
        coalesce(owner_phone_country, ''),
        coalesce(owner_phone_area, ''),
        coalesce(owner_phone_number, '')
      )
      else null
    end as owner_phone
  from {{ source('int_moltres','mwp_store_settings') }}
),

wp_users as (
  select
    store_id,
    id as main_user_id,
    user_email as user_email_wp,
    row_number() over (partition by store_id order by id desc) as rn
  from {{ source('int_moltres','wp_users') }}
),

latest_user as (
  select store_id, main_user_id, user_email_wp
  from wp_users
  where rn = 1
),

store_info as (
  select
    id as store_id,
    email_marketing as user_email_info
  from {{ source('int_moltres','mwp_store_info') }}
),

contacts as (
  select
    b.store_id,
    u.main_user_id,
    coalesce(u.user_email_wp, i.user_email_info) as email,
    s.phone,
    s.whatsapp,
    s.owner_phone
  from base b
  left join store_settings s on b.store_id = s.store_id
  left join latest_user   u on b.store_id = u.store_id
  left join store_info    i on b.store_id = i.store_id
),

-- SOCIAL
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
  select
    store_id,
    followers as instagram_followers,
    following,
    posts,
    case when posts_likes >= 0 then posts_likes else null end as posts_likes
  from ig_stats
  where rn = 1
),

social as (
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
)

-- OUTPUT UNIFICADO
select
  c.store_id,
  c.main_user_id,
  c.email,
  c.phone,
  c.whatsapp,
  c.owner_phone,
  s.instagram,
  s.instagram_followers,
  s.following,
  s.posts,
  s.posts_likes,
  s.facebook,
  s.twitter,
  s.tiktok,
  s.pinterest
from contacts c
left join social s using (store_id)

