-- Analysis of sessions to classify which ones are more likely to be from real end users


SELECT
   unique_session_key
   , base_date
   , FALSE AS is_end_user
FROM
   {{ ref('product__traffic__sessions__event') }}
WHERE
{% if 1 == 1 %}
   base_date = DATE('2024-09-23')
{% else %}
   base_date {{
    get_max_date_env_model(
      'product',
      's__traffic__session__event',
      'base_date',
      2, 'week',
      fallback_start='2024-01-01',
      fallback_end='2024-01-05'
    )
  }}
{% endif %}
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
