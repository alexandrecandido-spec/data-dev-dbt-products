-- Analysis of sessions to classify which ones are more likely to be from real end users
{% set force_start_var = var('force_start', None) %}

SELECT
   unique_session_key
   , base_date
   , FALSE AS is_end_user
FROM
   {{ ref('product__traffic__sessions__event') }}
WHERE
   base_date {{
    get_incremental_date(
      domain='product',
      table='s__traffic__session__event',
      date_field='base_date',
      fwd_value=1,
      fwd_unit='week',
      force_date=force_start_var
    )
  }}
AND
   -- exclude: likely from merchants creating their own design
   (
       http_referral LIKE '%conekta-tiendanube%'
       OR http_referral LIKE '%stats.tiendanube.com%'
       OR http_referral LIKE '%lojavirtualnuvem.com.br/admin%'
       OR http_referral LIKE '%mitiendanube.com/admin%'
       OR http_referral LIKE '%lojavirtualnuvem.com.br/?preview%'
       OR http_referral LIKE '%mitiendanube.com/?preview%'
       OR http_referral LIKE '%exit_preview_theme_installation%'
       OR http_referral LIKE '%.my.canva.site%'
       -- exclude: internal tools, automated agents, and non-browser sources
       OR (
          http_referral IS NOT NULL
           AND http_referral NOT LIKE 'http%'
           AND http_referral NOT LIKE 'www%'
           AND http_referral NOT LIKE 'android-app%'
           AND http_referral NOT LIKE 'ios-app%'
           AND http_referral NOT LIKE 'about:%'
           AND http_referral NOT LIKE 'file:%'
           )
       )
