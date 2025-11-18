{% set json_schema -%}
STRUCT<
  agent_ooo:BOOLEAN,
  equipe:STRING,
  has_store:BOOLEAN,
  identificacao:STRING,
  is_partner:BOOLEAN,
  no_recebe_e_mail:BOOLEAN,
  not_actually_a_partner:BOOLEAN,
  partner_id:BIGINT,
  partner_tags:STRING,
  perfil_cliente:STRING,
  user_filters:STRING,
  user_filters_campaigns:STRING,
  user_filters_fields:STRING,
  user_name_manual:STRING,
  _prodon__observacoes:STRING
>
{%- endset %}

WITH 
parsed_inc AS 
(
  SELECT u.*, FROM_JSON(u.user_fields, '{{ json_schema | trim }}') AS uf
  FROM {{ source('int_zendesk_support_prod', 'users') }} u
)
,tb_users AS
(
SELECT
 CAST(1 AS bigint) AS source_priority
,CAST(_airbyte_extracted_at AS date) AS airbyte_extracted_at
,CAST(id AS bigint) AS user_id
,CASE WHEN COALESCE(name,'') = '' THEN 'Not Informed' ELSE name END AS name
,NULLIF(trim(lower(email)), '') AS email
,NULLIF(role, '')  AS role
,NULLIF(phone, '') AS phone
,CAST(active AS boolean) AS active
,CAST(created_at AS timestamp) AS created_at
,CAST(updated_at AS timestamp) AS updated_at
,NULLIF(external_id, '')    AS external_id
,NULLIF(iana_time_zone, '') AS iana_time_zone
,NULLIF(locale, '') AS locale
,CAST(locale_id AS bigint) AS locale_id
,CAST(moderator AS boolean) AS moderator
,CAST(only_private_comments AS boolean) AS only_private_comments
,CAST(organization_id AS bigint) AS organization_id
,CAST(report_csv AS boolean) AS report_csv
,CAST(restricted_agent AS boolean) AS restricted_agent
,CAST(shared AS boolean) AS shared
,CAST(shared_agent AS boolean) AS shared_agent
,CAST(shared_phone_number AS boolean) AS shared_phone_number
,CAST(suspended AS boolean) AS suspended
,CAST(tags AS string) AS tags
,NULLIF(ticket_restriction, '') AS ticket_restriction
,NULLIF(time_zone, '') AS time_zone
,CAST(url AS string) AS url
,CAST(verified AS boolean) AS verified
,NULLIF(user_fields, '') AS user_fields
,uf.agent_ooo                          AS user_fields_agent_ooo
,uf.has_store                          AS user_fields_has_store
,uf.is_partner                         AS user_fields_is_partner
,uf.no_recebe_e_mail                   AS user_fields_no_recebe_e_mail
,uf.not_actually_a_partner             AS user_fields_not_actually_a_partner
FROM parsed_inc
)

{% if is_incremental() %}

    SELECT *
    FROM   tb_users 
    WHERE  airbyte_extracted_at >= (select coalesce(max(date(sys_audit_updated_on)), date('1900-01-01')) from {{ this }})

{% else %}

    ,parsed_legacy AS 
    (
      SELECT ul.*, FROM_JSON(ul.user_fields, '{{ json_schema | trim }}') AS ufl
      FROM {{ source('int_zendesk_support_prod', 'legacy_users') }} ul
    )
    ,tb_legacy AS
    (
    SELECT
     CAST(2 AS bigint) AS source_priority
    ,CAST(null AS date) AS airbyte_extracted_at
    ,CAST(id AS bigint) AS user_id
    ,CASE WHEN COALESCE(name,'') = '' THEN 'Not Informed' ELSE name END AS name
    ,NULLIF(trim(lower(email)), '') AS email
    ,NULLIF(role, '')  AS role
    ,NULLIF(phone, '') AS phone
    ,CAST(active AS boolean) AS active
    ,CAST(created_at AS timestamp) AS created_at
    ,CAST(updated_at AS timestamp) AS updated_at
    ,NULLIF(external_id, '')    AS external_id
    ,NULLIF(iana_time_zone, '') AS iana_time_zone
    ,NULLIF(locale, '') AS locale
    ,CAST(locale_id AS bigint) AS locale_id
    ,CAST(moderator AS boolean) AS moderator
    ,CAST(only_private_comments AS boolean) AS only_private_comments
    ,CAST(organization_id AS bigint) AS organization_id
    ,CAST(report_csv AS boolean) AS report_csv
    ,CAST(restricted_agent AS boolean) AS restricted_agent
    ,CAST(shared AS boolean) AS shared
    ,CAST(shared_agent AS boolean) AS shared_agent
    ,CAST(shared_phone_number AS boolean) AS shared_phone_number
    ,CAST(suspended AS boolean) AS suspended
    ,CAST(tags AS string) AS tags
    ,NULLIF(ticket_restriction, '') AS ticket_restriction
    ,NULLIF(time_zone, '') AS time_zone
    ,CAST(url AS string) AS url
    ,CAST(verified AS boolean) AS verified
    ,NULLIF(user_fields, '') AS user_fields
    ,ufl.agent_ooo                          AS user_fields_agent_ooo
    ,ufl.has_store                          AS user_fields_has_store
    ,ufl.is_partner                         AS user_fields_is_partner
    ,ufl.no_recebe_e_mail                   AS user_fields_no_recebe_e_mail
    ,ufl.not_actually_a_partner             AS user_fields_not_actually_a_partner
    FROM parsed_legacy
    )
    ,tb_final AS
    (
    SELECT * FROM tb_users UNION ALL SELECT * FROM tb_legacy
    )
    SELECT  *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY source_priority ASC, COALESCE(updated_at, created_at) DESC) AS rnk
    FROM    tb_final 
    qualify rnk = 1

{% endif %}