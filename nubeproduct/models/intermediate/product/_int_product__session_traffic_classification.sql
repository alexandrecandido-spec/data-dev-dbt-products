-- Classifies session-level traffic origin (`source_name`) and type (`traffic_type`).
-- Uses UTM parameters, referrers, landing pages, and domain signals.
--
-- Prioritizes precision over recall.
-- The channel that influenced or triggered the click prevails over the one that merely acted as a bridge.
-- High-confidence signals (e.g. gclid, strong UTMs) are classified first.
-- Direct traffic requires complete absence of UTMs and referrer.
-- Ambiguous or weak signals fall back to `'others'`.


WITH base_sessions AS (
SELECT
   unique_session_key
   , base_date
   , utm_source
   , utm_medium
   , utm_campaign
   , utm_term
   , utm_content
   , http_referral
   , landing_page
   , ref_domain
   , land_domain
FROM
   {{ ref('_int_product__session_with_domains') }}
)

, session_class AS (
SELECT
   *
   -- Classify source_name based on strongest available signals
   , CASE
        --1. Referrals and landing pages with stronger signals than utm_source and utm_medium
        WHEN http_referral LIKE '%gclid%' OR landing_page LIKE '%gclid%'    THEN 'google'             -- unequivocal signal of Google paid media
        WHEN http_referral LIKE '%ttclid%' OR landing_page LIKE '%ttclid%'  THEN 'tiktok'             -- unequivocal signal of TikTok paid media
        WHEN http_referral LIKE '%twclid%' OR landing_page LIKE '%twclid%'  THEN 'twitter'            -- unequivocal signal of Twitter paid media
        WHEN http_referral LIKE '%amazon-adsystem.com%' OR landing_page LIKE '%amazon-adsystem.com%' THEN 'amazon' -- sponsored ad from Amazon
        WHEN http_referral LIKE '%srsltid=%' OR landing_page LIKE '%srsltid=%' THEN 'bing'            -- unequivocal signal of Bing paid media

        -- 2. Strong utm_source + utm_medium: If UTMs are explicit and clearly indicate platforms like Meta or Instagram, they should prevail over generic http_referral like https://google.com/
        -- Meta cases (cross-signals between utm_source and utm_medium)
        WHEN utm_source LIKE '%meta%' OR utm_medium LIKE '%meta%' THEN 'meta'
        WHEN (utm_source LIKE '%ig%' OR utm_source LIKE '%insta%')
            AND (utm_source LIKE '%fb%' OR utm_source LIKE '%face%') THEN 'meta'
        WHEN (utm_medium LIKE '%ig%' OR utm_medium LIKE '%insta%')
            AND (utm_medium LIKE '%fb%' OR utm_medium LIKE '%face%') THEN 'meta'
        WHEN (utm_source LIKE '%ig%' OR utm_source LIKE '%insta%')
            AND (utm_medium LIKE '%fb%' OR utm_medium LIKE '%face%') THEN 'meta'
        WHEN (utm_source LIKE '%fb%' OR utm_source LIKE '%face%')
            AND (utm_medium LIKE '%ig%' OR utm_medium LIKE '%insta%') THEN 'meta'
        WHEN (utm_source LIKE '%fb%' OR utm_source LIKE '%face%')
            AND (utm_medium LIKE '%insta%' OR utm_content LIKE '%insta%' OR http_referral LIKE '%insta%') THEN 'meta'
        WHEN (utm_source LIKE '%ig%' OR utm_source LIKE '%insta%')
            AND (utm_medium LIKE '%facebook%' OR utm_content LIKE '%facebook%' OR http_referral LIKE '%facebook%') THEN 'meta'
        WHEN http_referral LIKE '%/meta.com%' THEN 'meta'

        -- Instagram
        WHEN utm_source IN ('ig', 'igads', 'ig_ads', 'ig-ads')
            OR utm_source LIKE '%insta%'
            OR utm_source LIKE '%igshopping%'
            OR utm_medium LIKE '%instagram%' THEN 'instagram'

        -- Facebook
        WHEN utm_source = 'fb'
            OR (utm_source LIKE '%fb%' AND utm_source LIKE '%ads%')
            OR (utm_source LIKE '%fb%' AND utm_medium LIKE '%paid%')
            OR (utm_source LIKE '%face%' AND utm_source LIKE '%ads%')
            OR (utm_source LIKE '%face%' AND utm_medium LIKE '%paid%')
            OR utm_source LIKE '%facebook%'
            OR utm_source LIKE '%fcbk%'
            OR utm_medium LIKE '%facebook%' 
            OR http_referral LIKE '%fbclid%' -- strong indicator, but positioned here to classify as Meta in ambiguous cases
            THEN 'facebook' 

        -- Google
        WHEN utm_source LIKE '%google%'
            OR utm_source LIKE '%gads%'
            OR utm_source = 'adwords'
            OR utm_source IN ('googlead', 'google-cpc') THEN 'google' 

        -- Other major channels via utm_source and utm_medium
        WHEN utm_source = 'nube_keyboard' THEN 'nube_keyboard' -- Nuvemshop keyboard
        WHEN utm_medium LIKE '%mail%' 
            OR utm_source LIKE '%mail%' 
            OR utm_medium LIKE '%newsletter%' 
            OR utm_source LIKE '%newsletter%' THEN 'email'
        WHEN (utm_source LIKE '%hubspot%' OR utm_source LIKE '%klaviyo%') AND (utm_medium LIKE '%email%' OR utm_campaign LIKE '%email%') THEN 'email'
        WHEN utm_source LIKE '%pinterest%' OR utm_medium LIKE '%pinterest%' THEN 'pinterest'
        WHEN utm_source LIKE '%tiktok%' 
            OR utm_source LIKE '%ttkads%' 
            OR utm_medium LIKE '%tiktok%' THEN 'tiktok'
        WHEN utm_source LIKE '%twitter%' OR utm_source LIKE '%x.com%' THEN 'twitter'
        WHEN utm_source LIKE '%bing%' THEN 'bing'

        WHEN utm_source LIKE '%chatgpt%' OR utm_source LIKE '%openai%' THEN 'chatgpt'
        WHEN utm_source LIKE '%gemini%' THEN 'gemini'
        WHEN http_referral LIKE '%claude.ai%'
            OR http_referral LIKE '%perplexity.ai%'
            OR http_referral LIKE '%beacons.ai%' 
            OR http_referral LIKE '%blackbox.ai%'
            OR http_referral LIKE '%copilot.microsoft.com%'
            THEN 'other ais'
        WHEN utm_source LIKE '%whatsapp%' AND http_referral LIKE '%whatsapp%' THEN 'whatsapp'
        WHEN utm_medium LIKE '%whatsapp%' AND http_referral LIKE '%whatsapp%' THEN 'whatsapp'
        WHEN utm_source LIKE 'whatsapp%' 
            AND (utm_medium LIKE '%whatsapp%' OR utm_campaign LIKE '%whatsapp%' OR utm_content LIKE '%whatsapp%') 
            THEN 'whatsapp'

        -- 3. Semantic reinforcement using utm_campaign, utm_term, and utm_content
        WHEN utm_campaign LIKE '%instagram%' OR utm_term LIKE '%instagram%' OR utm_content LIKE '%instagram%' THEN 'instagram'
        WHEN utm_campaign LIKE '%facebook%' OR utm_term LIKE '%facebook%' OR utm_content LIKE '%facebook%' THEN 'facebook' 
        WHEN REGEXP_LIKE(utm_campaign, 'gclid:?[a-zA-Z0-9_-]{10,}') THEN 'google'
        WHEN REGEXP_LIKE(utm_campaign, '\\b(google|pmax|shopping|gads|gclid)\\b') THEN 'google'
        WHEN REGEXP_LIKE(utm_campaign, '\\b(tiktok|ttkads|ttclid)\\b') THEN 'tiktok'

        -- 4. Fallback via http_referral
        WHEN http_referral LIKE '%instagram.com%' THEN 'instagram'
        WHEN http_referral LIKE '%facebook.com%' THEN 'facebook'

        WHEN http_referral LIKE '%gemini.google%' THEN 'gemini'
        WHEN http_referral LIKE '%chatgpt.com%' OR http_referral LIKE '%openai.com%' THEN 'chatgpt'
        WHEN http_referral LIKE '%claude.ai%'
            OR http_referral LIKE '%perplexity.ai%'
            OR http_referral LIKE '%beacons.ai%' 
            OR http_referral LIKE '%blackbox.ai%'
            OR http_referral LIKE '%copilot.microsoft.com%'
            THEN 'other ais'

        WHEN http_referral LIKE '%google%'
            OR http_referral LIKE '%adwords%'
            OR http_referral LIKE '%ads.google%'
            OR http_referral LIKE '%googlead%'
            OR http_referral LIKE '%syndicatedsearch.goog%'
            OR http_referral LIKE '%adsensecustomsearchads%' THEN 'google'
        WHEN http_referral LIKE '%youtube.com%' THEN 'youtube'

        WHEN http_referral LIKE '%pinterest.%' OR http_referral LIKE '%.pinterest%' THEN 'pinterest'
        WHEN http_referral LIKE '%tiktok.com%' THEN 'tiktok'
        WHEN http_referral LIKE '%t.co/%' 
            OR http_referral LIKE '%x.com%' 
            OR http_referral LIKE '%com.twitter%' THEN 'twitter'
        WHEN http_referral LIKE '%bing.com%' THEN 'bing'
        WHEN http_referral LIKE '%search.yahoo%' 
              OR http_referral LIKE '%search.brave.com%' 
              OR http_referral LIKE '%duckduckgo.com%' THEN 'other search engines'
        WHEN http_referral LIKE '%threads.com%' THEN 'threads'
        WHEN REGEXP_LIKE(http_referral, '(\/|\=|\.)(mail|email|mailing|webmail)(\.|\/|\=|$)')
            OR http_referral LIKE '%yahoomail%' THEN 'email'
        WHEN http_referral LIKE '%wl.co%' OR http_referral LIKE '%api.whatsapp%' THEN 'whatsapp'
        WHEN (http_referral IS NULL) AND (utm_source LIKE '%whatsapp%' OR utm_source LIKE '%wpp%') THEN 'whatsapp'
        WHEN (http_referral IS NULL) AND (utm_medium LIKE '%whatsapp%' OR utm_medium LIKE '%wpp%') THEN 'whatsapp'
        WHEN (http_referral IS NULL) AND (utm_campaign LIKE '%whatsapp%' OR utm_campaign LIKE '%wpp%') THEN 'whatsapp'

        -- 5. Fallback via landing_page
        WHEN landing_page LIKE '%srsltid=%' THEN 'bing'
        WHEN landing_page LIKE '%gclid=%' THEN 'google'  
        WHEN landing_page LIKE '%gbraid=%'
            OR landing_page LIKE '%gad_source=%' THEN 'google'
        WHEN landing_page LIKE '%fbclid%' THEN 'meta'

        -- 6. Other cases
        WHEN landing_page LIKE '%checkout/v%' 
            OR http_referral LIKE '%gocuotas%' 
            OR utm_source = 'gocuotas'
            OR http_referral LIKE '%checkout.pagar.me%'
            THEN 'checkout_related' -- link to or from checkout 
        WHEN http_referral LIKE 'android-app://%' OR http_referral LIKE 'ios-app://%' THEN 'app_referral'

        -- Links in bio
        WHEN http_referral LIKE '%linktr.ee%' THEN 'linktree'
        WHEN (http_referral IS NULL) AND (utm_source LIKE '%linktr%' OR utm_medium LIKE '%linktr%') THEN 'linktree'
        WHEN utm_source = 'linktree' OR http_referral LIKE '%linktr.ee%' THEN 'linktree'
        WHEN utm_source IN ('heylink.me', 'taplink', 'linkin.bio', 'bio.site', 'url.bio')
            OR http_referral LIKE '%olink.ai%'
            OR http_referral LIKE '%entr.ai%'
            OR http_referral LIKE '%heylink.me%'
            OR http_referral LIKE '%taplink%'
            OR http_referral LIKE '%bio.site%'
            OR http_referral LIKE '%instabio.cc%'
            OR http_referral LIKE '%insta-bio.%'
            OR http_referral LIKE '%linkin.bio%'
            OR http_referral LIKE '%linkfly.to%'
            OR http_referral LIKE '%biolink.info%'
            OR http_referral LIKE '%url.bio%'
            OR http_referral LIKE '%bio.link%'
            OR http_referral LIKE '%linkbio.co%'
            OR http_referral LIKE '%.bio/%'
            OR http_referral LIKE '%.bio.%'
            THEN 'other linkbios'

        -- 7. Direct
        WHEN (http_referral IS NULL OR http_referral = '')
            AND utm_source IS NULL AND utm_medium IS NULL
            AND utm_campaign IS NULL AND utm_term IS NULL AND utm_content IS NULL
            THEN 'direct'
        
        WHEN http_referral IS NOT NULL 
            AND landing_page IS NOT NULL
            AND utm_source IS NULL 
            AND utm_medium IS NULL
            AND REGEXP_REPLACE(http_referral, '^www\\.', '') = REGEXP_REPLACE(landing_page, '^www\\.', '')
            THEN 'direct'

        WHEN http_referral IS NOT NULL
            AND landing_page IS NOT NULL
            AND utm_source IS NULL
            AND utm_medium IS NULL
            AND (POSITION(ref_domain IN land_domain) > 0
                OR POSITION(land_domain IN ref_domain) > 0)
            THEN 'direct'

        -- 8. Fallback: sessions that aren't in any of the above cases
        ELSE 'others'
        END AS source_name

    -- Traffic type classification, prioritizing precision over recall
    , CASE
        -- 1. Unequivocal signals of paid media: reliable technical parameters
        WHEN http_referral LIKE '%gclid%'
            OR http_referral LIKE '%ttclid%'
            OR http_referral LIKE '%twclid%'
            OR http_referral LIKE '%fbclid%'
            OR http_referral LIKE '%ads.google%'
            OR http_referral LIKE '%googlead%'
            OR http_referral LIKE '%srsltid=%'
            OR landing_page LIKE '%gclid=%'
            OR landing_page LIKE '%ttclid=%'
            OR landing_page LIKE '%fbclid%'
            OR landing_page LIKE '%ads.google%'
            OR landing_page LIKE '%googlead%'
            OR landing_page LIKE '%srsltid=%'
            OR landing_page LIKE '%gbraid=%'
            OR landing_page LIKE '%gad_source=%'
            THEN 'paid'

        -- 2. Explicit indication of paid media in medium
        WHEN utm_medium IN (
            'cpc', 'ppc', 'cpa', 'paid', 'paidsocial', 'paid_social', 'social-paid',
            'display', 'affiliate', 'ads', 'adwords', 'shopping', 'pmax'
        ) THEN 'paid'

        -- 3. Reliable patterns in utm_source with contextual reinforcement
        WHEN utm_source IN ('googlead', 'google-cpc', 'adwords', 'googleads') THEN 'paid'
        WHEN utm_source = 'google' AND utm_medium LIKE '%sms%' THEN 'paid'
        WHEN utm_source LIKE '%google%' AND utm_medium IN ('cpc', 'pmax', 'shopping') THEN 'paid'

        -- 4. Campaigns with strong semantic reinforcement and paid structure
        WHEN REGEXP_LIKE(utm_campaign, '\\b(pmax|shopping|display|remarketing|retarget|gclid)\\b')
            AND utm_source LIKE '%google%' THEN 'paid'
        WHEN REGEXP_LIKE(utm_campaign, '\\b(ads|adv|rmkt)\\b')
            AND utm_medium LIKE '%paid%' THEN 'paid'
        WHEN REGEXP_LIKE(utm_campaign, '(^|_|-|/)(ad|ads)(_|-|/|$)')
            OR REGEXP_LIKE(utm_content, '(^|_|-|/)(ad|ads)(_|-|/|$)') THEN 'paid'

        -- 5. Numeric campaign structure (with reinforcement)
        WHEN REGEXP_LIKE(utm_campaign, '[0-9]{8,}')
            AND utm_medium LIKE '%paid%' THEN 'paid'
        WHEN REGEXP_LIKE(utm_campaign, '[0-9]{8,}')
            AND utm_source LIKE '%ads%' THEN 'paid'

        -- Default
        ELSE 'organic'
        END AS traffic_type
FROM
   base_sessions
)

, source_groups AS (
SELECT
    *
    , CASE      WHEN source_name IN ('facebook', 'instagram', 'meta', 'threads', 'whatsapp') THEN 'meta'
                WHEN source_name IN ('google', 'youtube') THEN 'alphabet'
                WHEN source_name IN ('chatgpt', 'gemini', 'other ais') THEN 'ai sources'
                WHEN source_name IN ('linktree', 'other linkbios') THEN 'link in bio'
                ELSE 'others'
                END AS source_group
    -- Hierarchy of Google Ads subchannels (order matters): pmax > shopping > display > youtube > search > ads > organic search
    , CASE WHEN source_name = 'google' AND traffic_type = 'paid' THEN CASE 
        WHEN utm_medium LIKE '%pmax%' 
            OR utm_campaign LIKE '%pmax%' 
            OR utm_campaign LIKE '%performance_max%' 
            OR utm_campaign LIKE '%google_performance%' 
            OR utm_campaign LIKE '%pmx%' THEN 'google_ads_pmax'
        WHEN utm_medium LIKE '%shopping%' 
            OR utm_campaign LIKE '%shopping%' THEN 'google_ads_shopping'
        WHEN utm_medium LIKE '%display%' 
            OR utm_campaign LIKE '%display%' THEN 'google_ads_display'
        WHEN utm_campaign LIKE '%youtube%' 
            AND utm_source LIKE '%google%' THEN 'google_ads_youtube'
        WHEN source_name = 'youtube' AND traffic_type = 'paid' THEN 'google_ads_youtube'
        WHEN utm_medium LIKE '%cpc%' 
            OR utm_campaign LIKE '%search%' 
            OR utm_campaign LIKE '%branded%' 
            OR utm_campaign LIKE '%generic%' THEN 'google_ads_search'
        ELSE 'google_ads_others' END
        WHEN source_name = 'google' THEN 'google_others'
        ELSE NULL END AS google_subchannel
FROM
    session_class
)

SELECT
   unique_session_key
   , base_date
   , source_name
   , source_group
   , google_subchannel
   , traffic_type
FROM
    source_groups
