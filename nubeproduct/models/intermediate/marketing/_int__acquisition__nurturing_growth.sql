WITH attribution_table AS (
    -- CTE 1: Seleciona e classifica o evento de clique e a loja
    SELECT
        -- 1. IDENTIFICADORES & DATAS
        att.store_id,           -- ID do merchant
        att.id AS click_id,     -- ID do evento de clique
        store.country_code,     -- Código do país da loja
        store.created_at,       -- Data de criação da loja
        lifecycle.first_payment, -- Data do primeiro pagamento
        lifecycle.first_seller_at, -- Data do primeiro venda
        lifecycle.new_seller, -- Flag de novo vendedor
        lifecycle.new_payment, -- Flag de novo pagamento
        
        -- 2. PARÂMETROS DE TRÁFEGO UTM & Referrer
        att.source,             -- Fonte do tráfego (utm_source)
        att.medium,             -- Meio do tráfego (utm_medium)
        att.campaign,           -- Campanha (utm_campaign)
        att.content,            -- Conteúdo (utm_content)
        att.http_referrer,      -- URL de origem do clique
        att.landing_page,       -- Página de destino
        att.device,             -- Dispositivo do usuário
        
        -- 3. CLASSIFICAÇÃO PRINCIPAL (SOURCE_CLICK)
        -- Classifica a origem do clique, priorizando 'Growth - Emails' com base em vários padrões.
        CASE
            WHEN 
                att.http_referrer LIKE '%utm_medium=education-email%'
                OR att.source LIKE '%expert-sender%'
                OR att.source LIKE '%email_marketing%'
                OR att.source LIKE '%Email_Marketing%'
                OR att.source LIKE '%education-email%'
                OR (att.source LIKE '%hubspot%' AND att.medium LIKE '%education-email%')
                OR (att.http_referrer LIKE '%hubspot%' AND att.medium LIKE '%education-email%')
                OR (att.http_referrer LIKE '%Hubspot%' AND att.medium LIKE '%education-email%')
                OR (att.campaign LIKE '%hubspot%' AND att.medium LIKE '%education-email%')
                OR (att.campaign LIKE '%Hubspot%' AND att.medium LIKE '%education-email%')
                OR (att.source ILIKE '%hubspot%' AND att.medium ILIKE '%newsletter%') 
                OR (att.source LIKE '%facebook%' AND att.campaign LIKE '%inbound-facebook-nurturing%')
                OR (att.source LIKE '%facebook%' AND att.campaign LIKE '%adhoc-dropshipping-mar21%')
                OR (att.source LIKE 'mandae' AND att.medium LIKE 'email')
                OR att.http_referrer LIKE '%utm_source=mandae&utm_medium=email%'
            THEN 'Growth - Emails'
            
            WHEN 
                att.source = utms.source
                AND att.medium = utms.medium 
            THEN (utms.source_mkt || ' ' || utms.subteam) -- Atribuição baseada na tabela UTMS
            
            ELSE 'Others'
        END AS source_click,

        -- 4. CLASSIFICAÇÃO SECUNDÁRIA (TIPO)
        -- Classificação detalhada para países LATAM (BR, MX, AR, CO, CL).
        CASE
            WHEN store.country_code IN ('BR', 'MX', 'AR', 'CO', 'CL') THEN
                CASE
                    -- Mandae
                    WHEN att.source LIKE '%mandae%' OR att.medium LIKE '%mandae%' OR att.http_referrer LIKE '%mandae%'
                    THEN 'Mandae'
                    
                    -- Newsletter
                    WHEN att.source ILIKE '%utm_campaign=newsletter%'
                    OR att.medium ILIKE '%newslet%'
                    OR att.campaign ILIKE '%newsletter%'
                    OR att.campaign ILIKE '%dailynews%'
                    OR att.http_referrer ILIKE '%utm_campaign=newsletter%'
                    OR att.http_referrer ILIKE '%dailynews%'
                    THEN 'Newsletter'
                    
                    -- Broadcast
                    WHEN att.source ILIKE '%utm_campaign=broadcast%'
                    OR att.campaign ILIKE '%broadcast%'
                    OR att.http_referrer ILIKE '%utm_campaign=broadcast%'
                    THEN 'Broadcast'
                    
                    -- Delivery
                    WHEN att.source ILIKE '%utm_campaign=deliver%'
                    OR att.campaign ILIKE '%deliver%' 
                    OR att.http_referrer ILIKE '%utm_campaign=deliver%'
                    THEN 'Delivery'
                    
                    ELSE 'Flux or Campaign'
                END
            ELSE NULL -- Nulo para outros países
        END AS tipo,
    
    GREATEST(att.sys_audit_updated_on, lifecycle.sys_audit_updated_on, store.sys_audit_updated_on) as change_timestamp
    FROM {{ ref('moltres__mwp_attribution') }} att
    LEFT JOIN {{ ref('s__general__mkt_attribution_github_inputs_utm__ref') }} utms
      ON att.source = utms.source 
     AND att.medium = utms.medium
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} store 
        ON store.store_id = att.store_id
    INNER JOIN {{ ref('s__lifecycle__store_status__ref') }} lifecycle 
        ON lifecycle.store_id = att.store_id
    WHERE store.created_at >= '2024-01-01' 
      AND store.created_at <= '2024-12-31'
      AND lifecycle.is_store_blocked = FALSE
),
flux_attribution AS (
    -- CTE 2: Classifica o 'flux' e filtra por 'Growth - Emails'
    SELECT DISTINCT
        ata.*,

        -- 5. Status do Fluxo (ativo/inativo)
        CASE
            WHEN ata.country_code IN ('BR', 'AR', 'MX') THEN gnc.status
            ELSE 'Others'
        END AS status,

        -- 6. CLASSIFICAÇÃO FLUX (flux)
        -- Classificação do fluxo de nutrição por prioridades (Tipo, Referrer, Newsletter, Campanha).
        CASE
            -- Prioridade 1: Classificação por 'tipo' (Mandae, Newsletter, etc.)
            WHEN ata.country_code IN ('BR', 'MX', 'AR', 'CO', 'CL')
            AND (ata.tipo IN ('Newsletter', 'Broadcast', 'Delivery', 'Mandae')) 
            THEN ata.tipo
                
            -- Prioridade 2: Classificação por http_referrer (baseado na tabela gnc)
            WHEN ata.country_code IN ('BR', 'MX') AND ata.http_referrer LIKE ('%' || gnc.campaign || '%') THEN gnc.flux
                
            -- Prioridade 3: Newsletter Geral (MX/AR)
            WHEN ata.country_code IN ('MX', 'AR') AND ata.campaign ILIKE '%newslet%' THEN 'Newsletter'
                
            -- Prioridade 4: Classificação Detalhada por Campanha
            WHEN ata.country_code = 'BR'
            AND ata.source LIKE '%hubspot%' AND ata.medium LIKE '%education-email%'
            AND ata.campaign NOT LIKE '%newsletter%' AND ata.campaign NOT LIKE '%broadcast%'
            AND ata.campaign NOT LIKE '%delivery%' AND ata.campaign = gnc.campaign 
            THEN gnc.flux
                
            WHEN ata.country_code = 'MX'
            AND ata.source LIKE '%hubspot%' AND ata.medium ILIKE '%education-email%'
            AND ata.campaign NOT LIKE '%newslet%' AND ata.campaign = gnc.campaign THEN gnc.flux
                
            WHEN ata.country_code = 'AR'
            AND ata.source LIKE '%hubspot%' AND ata.medium ILIKE '%education-email%'
            AND ata.campaign NOT LIKE '%newslet%' AND ata.campaign = gnc.campaign THEN gnc.flux
                
            ELSE 'Others'
        END AS flux,

        -- Número de linha para desduplicar cliques (mantém o store_id menor em caso de duplicidade)
        ROW_NUMBER() OVER (PARTITION BY ata.click_id ORDER BY ata.store_id) AS rn 

    FROM attribution_table AS ata
    LEFT JOIN {{ source('data_manual','ext__marketing__acquisition__growth_nurturing_campaings') }} gnc 
        ON ata.campaign = gnc.campaign
       AND ata.country_code = gnc.country
       AND ata.content = gnc.content
    WHERE ata.source_click = 'Growth - Emails'
),
final_attribution AS (
    -- CTE 3: Atribui o nome do e-mail e desduplica o clique
    SELECT 
        fa.*,

        -- 7. Atribuição do Nome do E-mail (email_name)
        CASE
            WHEN fa.country_code = 'BR'
            AND fa.campaign = gnc.campaign
            AND fa.content = gnc.content
            THEN gnc.email_name
            
            WHEN fa.country_code = 'BR' AND fa.flux = 'Chatbot Empresarial' THEN 'Chatbot Empresarial'
            
            WHEN fa.country_code = 'AR'
            AND fa.campaign = gnc.campaign
            AND fa.content = gnc.content 
            THEN gnc.email_name
            
            WHEN fa.country_code = 'MX'
            AND fa.campaign = gnc.campaign
            AND fa.content = gnc.content
            THEN gnc.email_name
            
            ELSE 'Others'
        END AS email_name,

        -- Flag para reter apenas 1 registro por click_id (em caso de store_id diferente)
        CASE
            WHEN ROW_NUMBER() OVER (PARTITION BY fa.click_id ORDER BY fa.store_id) = 1 THEN 1
            ELSE 0
        END AS rn_click
    
    FROM flux_attribution fa 
    LEFT JOIN {{ source('data_manual','ext__marketing__acquisition__growth_nurturing_campaings') }} gnc 
        ON fa.campaign = gnc.campaign
       AND fa.content = gnc.content
       AND fa.country_code = gnc.country
    WHERE fa.rn = 1 -- Mantém apenas o registro principal da desduplicação do CTE anterior
)
SELECT 
    * 
FROM 
    final_attribution 
WHERE 
    rn_click = 1