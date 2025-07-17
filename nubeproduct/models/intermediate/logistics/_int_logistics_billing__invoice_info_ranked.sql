WITH invoice_info AS (
    SELECT
        mi.store_id,
        mi.id_type,
        mi.id_number,
        mi.business_name,
        ROW_NUMBER() OVER (PARTITION BY mi.store_id ORDER BY type ASC) AS rnk
    FROM {{ ref('moltres__mwp_invoice_info') }} mi
    INNER JOIN {{ ref('moltres__mwp_store_info') }} si
        ON si.store_id = mi.store_id
)

SELECT
    store_id,
    id_type,
    id_number,
    business_name
FROM invoice_info
WHERE rnk = 1

