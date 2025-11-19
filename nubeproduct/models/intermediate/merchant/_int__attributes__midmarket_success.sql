/*
Intermediate Model: Mid Market Success Consolidation
Description: Consolida información de Mid Market Success (is_midmarket, rep) desde múltiples fuentes
Owner: jhu.boggio@tiendanube.com
Domain: merchant

Este modelo intermedio consolida la lógica de obtención de información de Mid Market Success:
- Flag is_midmarket: basado en in_portfolio de midmarket_success_stores
- Rep (representante): del registro más reciente en midmarket_weekly_business_review

El modelo SILVER solo consumirá este intermediate y manejará la incrementalidad.
*/

WITH 
-- Base: todas las tiendas desde store_core para tener la lista completa
all_stores AS (
    SELECT 
        store_id,
        sys_audit_updated_on
    FROM {{ ref('s__attributes__store_core__ref') }}
),

-- Información de Mid Market Success Stores
midmarket_stores AS (
    SELECT 
        store_id,
        in_portfolio,
        sys_audit_updated_on
    FROM {{ ref('midmarket_success_stores') }}
),

-- Rep más reciente de Weekly Business Review
latest_rep AS (
    SELECT 
        store_id,
        rep,
        date_from,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY date_from DESC) AS rn
    FROM {{ ref('midmarket_weekly_business_review') }}
    WHERE playbook NOT IN ('Effective churn', 'Out of portfolio')
)

SELECT
    as_base.store_id,
    
    -- Flag: es Mid Market?
    CASE 
        WHEN ms.in_portfolio = true THEN true 
        ELSE false 
    END AS is_midmarket,
    
    -- Rep más reciente (puede ser NULL si no está en WBR)
    lr.rep,
    
    -- Timestamp para incrementalidad (máximo entre las fuentes)
    GREATEST(
        as_base.sys_audit_updated_on,
        COALESCE(ms.sys_audit_updated_on, TIMESTAMP '1900-01-01'),
        COALESCE(CAST(lr.date_from AS TIMESTAMP), TIMESTAMP '1900-01-01')
    ) AS change_timestamp

FROM all_stores as_base
LEFT JOIN midmarket_stores ms ON as_base.store_id = ms.store_id
LEFT JOIN latest_rep lr ON as_base.store_id = lr.store_id AND lr.rn = 1

