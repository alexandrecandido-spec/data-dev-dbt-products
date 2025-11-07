WITH twig_template AS (
    SELECT 
    	CAST(store_id AS STRING) AS store_id,
    	option_value
    FROM {{ ref('moltres__mwp_options') }}
    WHERE option_name = 'twig_template' 
        AND DATE(created_at) >= DATE('2022-01-01')
),

app_install AS (
    select 
        CAST(store_id AS STRING) AS store_id,
        MIN(app_install_date) AS app_installed_at
    FROM {{ ref('moltres__platform_mwp_apps_stores') }}
    WHERE app_id = 2602
    GROUP BY store_id
)

SELECT 
    CAST(msi.store_id AS STRING) AS store_id,
    CAST(msi.created_at AS DATE) AS created_at,
    UPPER(msi.country) AS country,
    CAST(msi.first_payment AS DATE) AS first_payment,
    CASE 
        WHEN CAST(partner_id AS string) IS NULL THEN FALSE
        ELSE TRUE
    END AS is_affiliate,
    msi.is_store_blocked,
    temp.option_value,
    CASE 
        WHEN app.app_installed_at IS NULL THEN FALSE
        ELSE TRUE
    END AS is_app_installed,
    app.app_installed_at,
    CASE	
        WHEN msi.verified = 1 THEN 'Desktop'	
        WHEN msi.verified IN (4, 5, 6) THEN 'Mobile'
        WHEN msi.verified = 2 THEN 'App'
        WHEN msi.verified = 0 THEN 'Undefined'
        ELSE 'Tablet' 
    END AS device
FROM {{ ref('moltres__mwp_store_info') }} AS msi
LEFT JOIN twig_template AS temp
    ON msi.store_id = temp.store_id
LEFT JOIN app_install AS app 
    ON msi.store_id = app.store_id
WHERE CAST(msi.created_at AS DATE) >= DATE('2022-01-01')
