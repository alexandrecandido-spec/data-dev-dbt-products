WITH
br_invoices_base AS (
    SELECT
        mi.id AS legacy_invoice_id,
        mi.payment_id AS legacy_payment_id,
        mi.store_id,
        mi.date AS issued_at,
        mi.total AS gross_amount,
        0 AS perception_tax,
        mi.number as invoice_number,
        'invoice' AS document_type,
        'BR' AS country_code,
        mi.matrix as matrix
    FROM {{ source('int_moltres', 'mwp_invoices') }} mi
    WHERE mi.currency = 'BRL'
      AND mi.deleted_at IS NULL
      AND mi.date BETWEEN '2021-01-01' AND '2025-01-01'
),

ar_invoices_base AS (
    SELECT
        i.id AS legacy_invoice_id,
        i.payment_id AS legacy_payment_id,
        i.store_id,
        i.date AS issued_at,
        i.total AS gross_amount,
        COALESCE(pt.price, 0) AS perception_tax,
        i.number as invoice_number,
        'invoice' AS document_type,
        'AR' AS country_code,
        i.matrix as matrix
    FROM {{ source('int_moltres', 'mwp_invoices') }} i
    LEFT JOIN {{ source('int_moltres', 'mwp_payment_tax') }} pt ON pt.payment_id = i.payment_id
    WHERE i.currency = 'ARS'
      AND i.deleted_at IS NULL
      AND i.date BETWEEN '2021-01-01' AND '2025-01-01'
),

unioned_data AS (
    SELECT * FROM br_invoices_base
    UNION ALL
    SELECT * FROM ar_invoices_base
),

final AS (
    SELECT
        legacy_invoice_id,
        legacy_payment_id,
        store_id,
        issued_at,
        cast(document_type as string) as document_type,
        gross_amount,
        invoice_number,
        perception_tax,
        country_code,
        CASE
            WHEN country_code = 'AR' THEN (gross_amount - perception_tax) - (((gross_amount - perception_tax) * 21) / 121)
            ELSE gross_amount
        END AS net_amount,
        CASE
            WHEN country_code = 'BR' AND (
                instr(REPLACE(REPLACE(REPLACE(SUBSTRING(matrix, 19, 100), '\\u00f3', 'o'), '\\/', '-'), '\\u00ed', 'i'), 'Nuvem Shop') > 0 OR
                instr(REPLACE(REPLACE(REPLACE(SUBSTRING(matrix, 19, 100), '\\u00f3', 'o'), '\\/', '-'), '\\u00ed', 'i'), 'Aumento') > 0
            ) THEN 'Subscriptions'
            WHEN country_code = 'AR' AND (
                instr(REPLACE(REPLACE(REPLACE(SUBSTRING(matrix, 19, 100), '\\u00f3', 'o'), '\\/', '-'), '\\u00ed', 'i'), 'Tienda') > 0 OR
                instr(REPLACE(REPLACE(REPLACE(SUBSTRING(matrix, 19, 100), '\\u00f3', 'o'), '\\/', '-'), '\\u00ed', 'i'), 'Aumento') > 0
            ) THEN 'Subscriptions'
            WHEN document_type LIKE '%Credito%' THEN 'Credit Note'
            ELSE 'Others'
        END AS service_type
    FROM unioned_data
)

SELECT
    legacy_invoice_id,
    legacy_payment_id,
    store_id,
    issued_at,
    document_type,
    net_amount,
    country_code,
    invoice_number,
    service_type,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    CAST(date_format(issued_at, 'yyyyMMdd') AS INT) AS year_month_day_code
FROM final
WHERE service_type = 'Subscriptions'