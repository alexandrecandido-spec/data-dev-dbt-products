WITH parsed AS (
  SELECT
    request_id,
    error_group,
    error_code,
    error_detail
  FROM (
    SELECT
      request_id,
      exploded_json.error_group AS error_group,
      exploded_json.error_code AS error_code,
      error_item AS error_detail
    FROM (
      SELECT
        ir.request_id,
        explode(
          from_json(ir.rejected_request_reason, 'array<struct<error_group:string,error_code:string,errors:array<string>>>')
        ) AS exploded_json
      FROM {{ ref('product__invoicing__invoice_request__event') }} ir
    ) AS level1
    LATERAL VIEW explode(exploded_json.errors) AS error_item
  ) AS level2
)

SELECT
  p.request_id,
  ir.store_id,
  p.error_group,
  p.error_code,
  CASE
    WHEN p.error_detail RLIKE 'Tax configuration not found' THEN 'Tax config missing'
    WHEN p.error_detail RLIKE 'certificado digital (inv[aá]lido|v[aá]lido)' THEN 'Missing digital certificate'
    WHEN p.error_detail RLIKE 'certificado digital inválido' THEN 'Missing digital certificate'
    WHEN p.error_detail RLIKE 'Erro ao gerar dados do\(s\) produto\(s\)' THEN 'Product data generation error'
    WHEN p.error_detail RLIKE 'Erro ao gerar dados do\\(s\\) produto\\(s\\)' THEN 'Product data generation error'
    WHEN p.error_detail RLIKE 'Erro ao consultar dados do produto/variante' THEN 'Product/variant lookup failed'
    WHEN p.error_detail RLIKE 'Rejeição:.*IE do emitente inválida' THEN 'Invalid IE of issuer'
    WHEN p.error_detail RLIKE 'Rejei[cç][aã]o:.*IE do emitente inv[aá]lida' THEN 'Invalid IE of issuer'
    WHEN p.error_detail RLIKE 'CFOP inválido para emitente MEI' THEN 'Invalid CFOP for MEI'
    WHEN p.error_detail RLIKE 'CFOP inv[aá]lido para emitente MEI' THEN 'Invalid CFOP for MEI'
    WHEN p.error_detail RLIKE 'CST.*incompat[ií]vel|CSOSN incompat[ií]vel' THEN 'Incompatible tax code (CST/CSOSN)'
    WHEN p.error_detail RLIKE 'Rejeição:.*CSOSN incompatível' THEN 'Incompatible CSOSN'
    WHEN p.error_detail RLIKE 'Rejeição:.*CST.*incompatível' THEN 'Incompatible CST'
    WHEN p.error_detail RLIKE 'store[_]?id.*variant[_]?id' THEN 'Tax config missing'
    WHEN p.error_detail RLIKE 'Descrição do Produto.*exceder 120 caracteres' THEN 'Product description too long'
    WHEN p.error_detail RLIKE 'The .+ element has an invalid value' THEN 'Invalid XML element value'
    WHEN p.error_detail RLIKE 'Falha no Schema XML' THEN 'Invalid XML schema'
    WHEN p.error_detail RLIKE 'Início da validação.*Final da validação' THEN 'Schema validation failed'
    WHEN p.error_detail RLIKE 'Não foi possível calcular o CFOP' THEN 'Unable to calculate CFOP'
    WHEN p.error_detail RLIKE 'Não informado o Grupo de Autorização' THEN 'Missing authorization group'
    WHEN p.error_detail RLIKE 'nota fiscal já autorizada' THEN 'Duplicate NF-e number'
    WHEN p.error_detail RLIKE 'Número do Documento do Cliente.*caracteres' THEN 'Invalid client document length'
    WHEN p.error_detail RLIKE 'cartao de credito/debito' THEN 'Missing credit/debit card info'
    WHEN p.error_detail RLIKE 'cEANTrib|cEAN.*invalid value' THEN 'Invalid barcode format (EAN)'
    WHEN p.error_detail RLIKE 'Falha no Schema XML' THEN 'Invalid XML schema'
    WHEN p.error_detail RLIKE 'The .+ element has an invalid value' THEN 'Invalid XML element value'
    WHEN p.error_detail RLIKE 'valor dos pagamentos.*menor que o total da nota' THEN 'Payment value below invoice total'
    WHEN p.error_detail RLIKE 'Aus[êe]ncia de troco' THEN 'Missing change value'
    WHEN p.error_detail RLIKE 'nota fiscal j[aá] autorizada' THEN 'Duplicate NF-e number'
    WHEN p.error_detail RLIKE 'NCM vazio|inv[aá]lido' THEN 'Invalid or missing NCM'
    WHEN p.error_detail RLIKE 'Cannot invoke .*getProductType\(\)' THEN 'Null product type in tax config'
    WHEN p.error_detail RLIKE 'Nao informados os dados do cart[aã]o' THEN 'Missing credit/debit card info'
    WHEN p.error_detail RLIKE 'Erro ao gerar a nota fiscal' THEN 'Invoice generation error'
    WHEN p.error_detail RLIKE 'The originState and destinationState must be provided' THEN 'Missing tax state info'
    WHEN p.error_detail RLIKE 'Não foi possível calcular o CFOP' THEN 'Unable to calculate CFOP'     
    ELSE 'Other / Unclassified'
END AS error_type,
  error_detail,

  TRIM(
    REGEXP_REPLACE(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                REGEXP_REPLACE(
                  REGEXP_REPLACE(
                    REGEXP_REPLACE(
                      error_detail,
                      'Produtos\\[\\d+\\]\\.', ''),                                          -- Remove Produtos[1].
                    'store[_]?id=\\d+|store[_]?id: ?\\[?\\d+\\]?', ''),                      -- storeId=... / store_id: [...]
                  'variant[_]?id=\\d+|variant[_]?id: ?\\[?\\d+\\]?', ''),                    -- variantId or variant_id
                'Documento:.*?Final da validação', ''),                                     -- Remove long Documento: ... XML
              '\\bnota\\b.*?\\d+', ''),                                                     -- Remove "nota fiscal ..." with numbers
            '\\bnfe\\.xml\\b.*', ''),                                                      -- Remove "nfe.xml" and trailing parts
          '\\d{6,}', ''),                                                                   -- Remove long numbers (like invoice or variant IDs)
        '[\\[\\]\\(\\)\\{\\}\\<\\>\\"]+', ''),                                              -- Remove bracketed content
      '[,:;]\\s*$', '')                                                                     -- Trim trailing punctuation
  ) AS error_normalized,
  COALESCE(ir.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)) AS sys_audit_updated_on

FROM parsed p
JOIN {{ ref('product__invoicing__invoice_request__event') }} ir
    ON ir.request_id = p.request_id